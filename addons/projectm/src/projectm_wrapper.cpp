#include "projectm_wrapper.h"
#include "projectm_param_access.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

// projectM v4 C API
#include <projectM-4/projectM.h>
#include <projectM-4/core.h>
#include <projectM-4/audio.h>
#include <projectM-4/parameters.h>
#include <projectM-4/render_opengl.h>
#include <projectM-4/memory.h>

#include <SDL2/SDL.h>

#ifdef __APPLE__
#define GL_SILENCE_DEPRECATION
#include <OpenGL/gl3.h>
#elif defined(_WIN32)
#include <GL/gl.h>
#else
#include <GL/gl.h>
#endif

using namespace godot;

void ProjectMWrapper::_bind_methods() {
    ClassDB::bind_method(D_METHOD("initialize", "width", "height"), &ProjectMWrapper::initialize);
    ClassDB::bind_method(D_METHOD("shutdown"), &ProjectMWrapper::shutdown);
    ClassDB::bind_method(D_METHOD("is_initialized"), &ProjectMWrapper::is_initialized);
    ClassDB::bind_method(D_METHOD("load_preset", "path"), &ProjectMWrapper::load_preset);
    ClassDB::bind_method(D_METHOD("get_preset_name"), &ProjectMWrapper::get_preset_name);
    ClassDB::bind_method(D_METHOD("feed_audio", "samples"), &ProjectMWrapper::feed_audio);
    ClassDB::bind_method(D_METHOD("render_frame"), &ProjectMWrapper::render_frame);
    ClassDB::bind_method(D_METHOD("get_texture"), &ProjectMWrapper::get_texture);
    ClassDB::bind_method(D_METHOD("set_viewport_size", "width", "height"), &ProjectMWrapper::set_viewport_size);
    // v4 parameter control
    ClassDB::bind_method(D_METHOD("set_param", "name", "value"), &ProjectMWrapper::set_param);
    ClassDB::bind_method(D_METHOD("get_param", "name"), &ProjectMWrapper::get_param);
    ClassDB::bind_method(D_METHOD("set_q_variable", "index", "value"), &ProjectMWrapper::set_q_variable);
    ClassDB::bind_method(D_METHOD("get_q_variable", "index"), &ProjectMWrapper::get_q_variable);
}

ProjectMWrapper::ProjectMWrapper() {
}

ProjectMWrapper::~ProjectMWrapper() {
    shutdown();
}

// --- SDL2-based offscreen GL context ---

bool ProjectMWrapper::_create_gl_context() {
    if (SDL_WasInit(SDL_INIT_VIDEO) == 0) {
        if (SDL_Init(SDL_INIT_VIDEO) < 0) {
            ERR_PRINT(String("ProjectMWrapper: SDL_Init failed: ") + SDL_GetError());
            return false;
        }
    }

    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 2);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
    SDL_GL_SetAttribute(SDL_GL_RED_SIZE, 8);
    SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE, 8);
    SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE, 8);
    SDL_GL_SetAttribute(SDL_GL_ALPHA_SIZE, 8);
    SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);
    SDL_GL_SetAttribute(SDL_GL_STENCIL_SIZE, 8);
    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);

    SDL_Window *window = SDL_CreateWindow(
        "projectM offscreen",
        SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
        _width, _height,
        SDL_WINDOW_OPENGL | SDL_WINDOW_HIDDEN
    );

    if (!window) {
        ERR_PRINT(String("ProjectMWrapper: SDL_CreateWindow failed: ") + SDL_GetError());
        return false;
    }

    SDL_GLContext gl_ctx = SDL_GL_CreateContext(window);
    if (!gl_ctx) {
        ERR_PRINT(String("ProjectMWrapper: SDL_GL_CreateContext failed: ") + SDL_GetError());
        SDL_DestroyWindow(window);
        return false;
    }

    _sdl_window = (void *)window;
    _sdl_gl_context = (void *)gl_ctx;

    SDL_GL_MakeCurrent(window, gl_ctx);

    const char *gl_version = (const char *)glGetString(GL_VERSION);
    const char *gl_renderer = (const char *)glGetString(GL_RENDERER);
    UtilityFunctions::print("ProjectMWrapper: SDL GL context created");
    UtilityFunctions::print("  GL Version: ", gl_version ? gl_version : "unknown");
    UtilityFunctions::print("  GL Renderer: ", gl_renderer ? gl_renderer : "unknown");

    glViewport(0, 0, _width, _height);

    return true;
}

void ProjectMWrapper::_destroy_gl_context() {
    if (_sdl_gl_context) {
        SDL_GL_DeleteContext((SDL_GLContext)_sdl_gl_context);
        _sdl_gl_context = nullptr;
    }
    if (_sdl_window) {
        SDL_DestroyWindow((SDL_Window *)_sdl_window);
        _sdl_window = nullptr;
    }
}

void ProjectMWrapper::_make_gl_current() {
    if (_sdl_window && _sdl_gl_context) {
        SDL_GL_MakeCurrent((SDL_Window *)_sdl_window, (SDL_GLContext)_sdl_gl_context);
    }
}

bool ProjectMWrapper::_create_fbo() {
    glGenFramebuffers(1, &_fbo);
    glGenTextures(1, &_fbo_color_tex);
    glGenRenderbuffers(1, &_fbo_depth_rb);

    glBindTexture(GL_TEXTURE_2D, _fbo_color_tex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, _width, _height, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    glBindRenderbuffer(GL_RENDERBUFFER, _fbo_depth_rb);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, _width, _height);

    glBindFramebuffer(GL_FRAMEBUFFER, _fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _fbo_color_tex, 0);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, _fbo_depth_rb);

    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        ERR_PRINT(String("ProjectMWrapper: FBO incomplete, status=") + String::num_int64(status));
        return false;
    }

    UtilityFunctions::print("ProjectMWrapper: created FBO ", _fbo, " (", _width, "x", _height, ") color_tex=", _fbo_color_tex);
    return true;
}

void ProjectMWrapper::_destroy_fbo() {
    if (_fbo) {
        glDeleteFramebuffers(1, &_fbo);
        _fbo = 0;
    }
    if (_fbo_color_tex) {
        glDeleteTextures(1, &_fbo_color_tex);
        _fbo_color_tex = 0;
    }
    if (_fbo_depth_rb) {
        glDeleteRenderbuffers(1, &_fbo_depth_rb);
        _fbo_depth_rb = 0;
    }
}

// --- Core API ---

bool ProjectMWrapper::initialize(int width, int height) {
    if (_initialized) {
        WARN_PRINT("ProjectMWrapper: already initialized, call shutdown() first");
        return false;
    }

    _width = width;
    _height = height;

    // Step 1: Create offscreen GL context
    if (!_create_gl_context()) {
        ERR_PRINT("ProjectMWrapper: failed to create offscreen GL context");
        return false;
    }

    // Step 2: Create FBO
    if (!_create_fbo()) {
        ERR_PRINT("ProjectMWrapper: failed to create FBO");
        _destroy_gl_context();
        return false;
    }
    glBindFramebuffer(GL_FRAMEBUFFER, _fbo);
    glViewport(0, 0, _width, _height);

    // Step 3: Create projectM v4 instance (requires active GL context)
    _pm = projectm_create();
    if (!_pm) {
        ERR_PRINT("ProjectMWrapper: failed to create projectM v4 instance");
        _destroy_fbo();
        _destroy_gl_context();
        return false;
    }

    // Configure v4 settings via C API
    projectm_set_window_size(_pm, _width, _height);
    projectm_set_mesh_size(_pm, 48, 36);
    projectm_set_fps(_pm, 60);
    projectm_set_soft_cut_duration(_pm, 5.0);
    projectm_set_preset_duration(_pm, 30.0);
    projectm_set_hard_cut_enabled(_pm, false);
    projectm_set_aspect_correction(_pm, true);
    projectm_set_beat_sensitivity(_pm, 1.0f);
    projectm_set_preset_locked(_pm, true); // We manage presets ourselves

    // Set texture search paths (for preset textures)
    const char* tex_paths[] = {
        "/opt/homebrew/share/projectM/textures",
        "/opt/homebrew/share/projectM"
    };
    projectm_set_texture_search_paths(_pm, tex_paths, 2);

    // Allocate pixel readback buffer and texture
    _pixel_buffer.resize(_width * _height * 4);

    Ref<Image> img = Image::create(_width, _height, false, Image::FORMAT_RGBA8);
    _texture.instantiate();
    _texture->set_image(img);

    _initialized = true;

    // Print version
    char* ver = projectm_get_version_string();
    UtilityFunctions::print("ProjectMWrapper: v4 initialized (", _width, "x", _height, ") version=", ver ? ver : "unknown");
    if (ver) projectm_free_string(ver);

    return true;
}

void ProjectMWrapper::shutdown() {
    if (_pm) {
        _make_gl_current();
        projectm_destroy(_pm);
        _pm = nullptr;
    }
    _destroy_fbo();
    _destroy_gl_context();
    _initialized = false;
    _texture.unref();
    _pixel_buffer.resize(0);
}

bool ProjectMWrapper::is_initialized() const {
    return _initialized;
}

bool ProjectMWrapper::load_preset(const String &path) {
    if (!_initialized || !_pm) {
        ERR_PRINT("ProjectMWrapper: not initialized");
        return false;
    }

    // Resolve Godot resource paths to absolute filesystem paths
    String abs_path = path;
    if (path.begins_with("res://") || path.begins_with("user://")) {
        abs_path = ProjectSettings::get_singleton()->globalize_path(path);
    }

    std::string preset_path = abs_path.utf8().get_data();

    _make_gl_current();
    glBindFramebuffer(GL_FRAMEBUFFER, _fbo);

    projectm_load_preset_file(_pm, preset_path.c_str(), true);

    UtilityFunctions::print("ProjectMWrapper: loaded preset '", abs_path, "'");
    return true;
}

String ProjectMWrapper::get_preset_name() const {
    // v4 doesn't have a direct "get current preset name" in the C API.
    // We'd need to track it ourselves. Return empty for now.
    return String();
}

void ProjectMWrapper::feed_audio(const PackedFloat32Array &samples) {
    if (!_initialized || !_pm) return;
    if (samples.size() == 0) return;

    // v4: projectm_pcm_add_float(handle, samples, count_per_channel, channels)
    if (samples.size() % 2 == 0) {
        projectm_pcm_add_float(_pm, samples.ptr(), samples.size() / 2, PROJECTM_STEREO);
    } else {
        projectm_pcm_add_float(_pm, samples.ptr(), samples.size(), PROJECTM_MONO);
    }
}

void ProjectMWrapper::render_frame() {
    if (!_initialized || !_pm) return;

    _make_gl_current();

    glBindFramebuffer(GL_FRAMEBUFFER, _fbo);
    glViewport(0, 0, _width, _height);

    projectm_opengl_render_frame(_pm);

    // Re-bind our FBO in case projectM changed it
    GLint active_fbo = 0;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &active_fbo);
    if ((GLuint)active_fbo != _fbo) {
        glBindFramebuffer(GL_FRAMEBUFFER, _fbo);
        glViewport(0, 0, _width, _height);
    }

    glFinish();

    // Read pixels
    glBindFramebuffer(GL_READ_FRAMEBUFFER, _fbo);
    glReadBuffer(GL_COLOR_ATTACHMENT0);
    glReadPixels(0, 0, _width, _height, GL_RGBA, GL_UNSIGNED_BYTE, _pixel_buffer.ptrw());

    // Debug output (first few frames + periodic)
    bool should_debug = _debug_frame < 5 || (_debug_frame >= 55 && _debug_frame < 60)
        || (_debug_frame % 300 == 0);
    if (should_debug) {
        const uint8_t *px = _pixel_buffer.ptr();
        int total = _width * _height;
        int nonzero = 0;
        long r_sum = 0, g_sum = 0, b_sum = 0;
        for (int i = 0; i < total; i++) {
            int idx = i * 4;
            if (px[idx] > 0 || px[idx+1] > 0 || px[idx+2] > 0) nonzero++;
            r_sum += px[idx]; g_sum += px[idx+1]; b_sum += px[idx+2];
        }
        UtilityFunctions::print("ProjectMWrapper: frame ", _debug_frame,
            " nonzero=", nonzero, "/", total,
            " avg_rgb=(", (int)(r_sum/total), ",", (int)(g_sum/total), ",", (int)(b_sum/total), ")");
    }
    _debug_frame++;

    // Flip vertically (GL bottom-up → Godot top-down)
    int row_bytes = _width * 4;
    uint8_t *buf = _pixel_buffer.ptrw();
    for (int y = 0; y < _height / 2; y++) {
        int top = y * row_bytes;
        int bot = (_height - 1 - y) * row_bytes;
        for (int x = 0; x < row_bytes; x++) {
            uint8_t tmp = buf[top + x];
            buf[top + x] = buf[bot + x];
            buf[bot + x] = tmp;
        }
    }

    Ref<Image> img = Image::create_from_data(_width, _height, false, Image::FORMAT_RGBA8, _pixel_buffer);
    if (img.is_valid() && _texture.is_valid()) {
        _texture->update(img);
    }
}

Ref<ImageTexture> ProjectMWrapper::get_texture() const {
    return _texture;
}

void ProjectMWrapper::set_viewport_size(int width, int height) {
    if (!_initialized || !_pm) return;

    _make_gl_current();

    _width = width;
    _height = height;

    _destroy_fbo();
    _create_fbo();
    glBindFramebuffer(GL_FRAMEBUFFER, _fbo);

    projectm_set_window_size(_pm, width, height);

    _pixel_buffer.resize(width * height * 4);

    UtilityFunctions::print("ProjectMWrapper: viewport resized to ", width, "x", height);
}

// --- Runtime parameter control ---

bool ProjectMWrapper::set_param(const String &name, float value) {
    if (!_initialized || !_pm) return false;
    std::string param_name = name.utf8().get_data();
    return projectm_set_preset_param(_pm, param_name.c_str(), value);
}

float ProjectMWrapper::get_param(const String &name) const {
    if (!_initialized || !_pm) return 0.0f;
    std::string param_name = name.utf8().get_data();
    return projectm_get_preset_param(_pm, param_name.c_str());
}

bool ProjectMWrapper::set_q_variable(int index, float value) {
    if (!_initialized || !_pm) return false;
    return projectm_set_q_variable(_pm, index, value);
}

float ProjectMWrapper::get_q_variable(int index) const {
    if (!_initialized || !_pm) return 0.0f;
    return projectm_get_q_variable(_pm, index);
}
