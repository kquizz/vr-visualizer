#include "projectm_wrapper.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <libprojectM/projectM.hpp>

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
}

ProjectMWrapper::ProjectMWrapper() {
}

ProjectMWrapper::~ProjectMWrapper() {
    shutdown();
}

// --- SDL2-based offscreen GL context ---
// Uses a hidden SDL window to get a proper GL context with a valid default
// framebuffer (FBO 0). This matches exactly what projectMSDL does internally.

bool ProjectMWrapper::_create_gl_context() {
    if (SDL_WasInit(SDL_INIT_VIDEO) == 0) {
        if (SDL_Init(SDL_INIT_VIDEO) < 0) {
            ERR_PRINT(String("ProjectMWrapper: SDL_Init failed: ") + SDL_GetError());
            return false;
        }
    }

    // Request GL 3.2 Core profile (macOS promotes to 4.1)
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

    // Create a hidden SDL window purely for GL context creation.
    // We render to our own FBO, not the window's backbuffer.
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
    // Create our own FBO so projectM renders into a valid surface
    // (hidden SDL window backbuffer is 0x0 or invalid on macOS)
    glGenFramebuffers(1, &_fbo);
    glGenTextures(1, &_fbo_color_tex);
    glGenRenderbuffers(1, &_fbo_depth_rb);

    // Color attachment
    glBindTexture(GL_TEXTURE_2D, _fbo_color_tex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, _width, _height, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    // Depth+stencil attachment (projectM uses depth)
    glBindRenderbuffer(GL_RENDERBUFFER, _fbo_depth_rb);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, _width, _height);

    // Assemble FBO
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

    // Step 1: Create offscreen GL context BEFORE projectM
    if (!_create_gl_context()) {
        ERR_PRINT("ProjectMWrapper: failed to create offscreen GL context");
        return false;
    }

    // Step 2: Create projectM (now has a valid GL context)
    projectM::Settings settings;
    settings.windowWidth = width;
    settings.windowHeight = height;
    settings.meshX = 48;
    settings.meshY = 36;
    settings.fps = 60;
    settings.textureSize = width;
    settings.smoothPresetDuration = 5;
    settings.presetDuration = 30;
    settings.hardcutEnabled = false;
    settings.aspectCorrection = true;
    settings.shuffleEnabled = false;
    settings.softCutRatingsEnabled = false;
    settings.easterEgg = 0.0f;
    settings.beatSensitivity = 1.0f;

    // projectM needs datadir for fonts/textures and presetURL for preset search
    settings.datadir = "/opt/homebrew/share/projectM";
    settings.presetURL = "/opt/homebrew/share/projectM/presets";
    settings.titleFontURL = "/opt/homebrew/share/projectM/fonts/Vera.ttf";
    settings.menuFontURL = "/opt/homebrew/share/projectM/fonts/VeraMono.ttf";

    UtilityFunctions::print("ProjectMWrapper: datadir = ", settings.datadir.c_str());
    UtilityFunctions::print("ProjectMWrapper: presetURL = ", settings.presetURL.c_str());

    // Create our own FBO for projectM to render into.
    // This avoids all double-buffer/swap issues with the SDL window.
    if (!_create_fbo()) {
        ERR_PRINT("ProjectMWrapper: failed to create FBO");
        _destroy_gl_context();
        return false;
    }
    glBindFramebuffer(GL_FRAMEBUFFER, _fbo);
    glViewport(0, 0, _width, _height);

    _pm = new projectM(settings, projectM::FLAG_DISABLE_PLAYLIST_LOAD);

    if (!_pm) {
        ERR_PRINT("ProjectMWrapper: failed to create projectM instance");
        _destroy_fbo();
        _destroy_gl_context();
        return false;
    }

    _pm->projectM_resetGL(_width, _height);
    UtilityFunctions::print("ProjectMWrapper: called projectM_resetGL(", _width, ",", _height, ")");

    _pixel_buffer.resize(_width * _height * 4);

    Ref<Image> img = Image::create(_width, _height, false, Image::FORMAT_RGBA8);
    _texture.instantiate();
    _texture->set_image(img);

    _initialized = true;
    UtilityFunctions::print("ProjectMWrapper: initialized (", _width, "x", _height, ") FBO mode, fbo=", _fbo);
    return true;
}

void ProjectMWrapper::shutdown() {
    if (_pm) {
        _make_gl_current();
        delete _pm;
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

    // projectM v3: add preset URL to playlist, then select it
    std::string preset_path = abs_path.utf8().get_data();
    std::string preset_name = abs_path.get_file().utf8().get_data();

    // Build a rating list (required by API)
    RatingList ratings(TOTAL_RATING_TYPES, 3);

    unsigned int index = _pm->addPresetURL(preset_path, preset_name, ratings);
    _pm->selectPreset(index, true);

    UtilityFunctions::print("ProjectMWrapper: loaded preset '", abs_path, "'");
    return true;
}

String ProjectMWrapper::get_preset_name() const {
    if (!_initialized || !_pm) {
        return String();
    }

    unsigned int index = 0;
    if (_pm->selectedPresetIndex(index)) {
        std::string name = _pm->getPresetName(index);
        return String(name.c_str());
    }
    return String();
}

void ProjectMWrapper::feed_audio(const PackedFloat32Array &samples) {
    if (!_initialized || !_pm) {
        return;
    }

    if (samples.size() == 0) {
        return;
    }

    // projectM v3: PCM::addPCMfloat expects mono float samples
    // For stereo interleaved data, use addPCMfloat_2ch
    PCM *pcm = _pm->pcm();
    if (!pcm) {
        return;
    }

    if (samples.size() % 2 == 0) {
        // Stereo interleaved
        pcm->addPCMfloat_2ch(samples.ptr(), samples.size() / 2);
    } else {
        // Mono
        pcm->addPCMfloat(samples.ptr(), samples.size());
    }
}

void ProjectMWrapper::render_frame() {
    if (!_initialized || !_pm) {
        return;
    }

    // Ensure our offscreen GL context is current
    _make_gl_current();

    // Bind our FBO — projectM renders to whatever FBO is currently bound.
    // Using our own FBO avoids double-buffer issues with the SDL window.
    glBindFramebuffer(GL_FRAMEBUFFER, _fbo);
    glViewport(0, 0, _width, _height);

    _pm->renderFrame();

    // projectM may have changed the FBO binding during its internal passes.
    // Re-bind our FBO before readback.
    GLint active_fbo = 0;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &active_fbo);
    if ((GLuint)active_fbo != _fbo) {
        UtilityFunctions::print("ProjectMWrapper: FBO clobbered! was=", active_fbo, " expected=", _fbo, " re-binding");
        glBindFramebuffer(GL_FRAMEBUFFER, _fbo);
        glViewport(0, 0, _width, _height);
    }

    glFinish();  // Ensure rendering is complete before readback

    // Read pixels directly from our FBO
    glBindFramebuffer(GL_READ_FRAMEBUFFER, _fbo);
    glReadBuffer(GL_COLOR_ATTACHMENT0);
    glReadPixels(0, 0, _width, _height, GL_RGBA, GL_UNSIGNED_BYTE, _pixel_buffer.ptrw());

    // Debug: sample pixels at startup, then every 5 seconds (300 frames at 60fps)
    bool should_debug = _debug_frame < 5 || (_debug_frame >= 55 && _debug_frame < 60)
        || (_debug_frame % 300 == 0);
    if (should_debug) {
        const uint8_t *px = _pixel_buffer.ptr();
        int total = _width * _height;
        int nonzero = 0;
        long r_sum = 0, g_sum = 0, b_sum = 0;
        for (int i = 0; i < total; i++) {
            int idx = i * 4;
            if (px[idx] > 0 || px[idx+1] > 0 || px[idx+2] > 0) {
                nonzero++;
            }
            r_sum += px[idx];
            g_sum += px[idx+1];
            b_sum += px[idx+2];
        }
        int avg_r = (int)(r_sum / total);
        int avg_g = (int)(g_sum / total);
        int avg_b = (int)(b_sum / total);
        // Check current FBO binding
        GLint current_fbo = 0;
        glGetIntegerv(GL_FRAMEBUFFER_BINDING, &current_fbo);
        UtilityFunctions::print("ProjectMWrapper: frame ", _debug_frame,
            " nonzero=", nonzero, "/", total,
            " avg_rgb=(", avg_r, ",", avg_g, ",", avg_b, ")",
            " fbo_after_render=", current_fbo);
    }
    _debug_frame++;

    // Flip image vertically (GL reads bottom-up, Godot expects top-down)
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
    if (!_initialized || !_pm) {
        return;
    }

    _make_gl_current();

    _width = width;
    _height = height;

    // Recreate FBO at new size
    _destroy_fbo();
    _create_fbo();
    glBindFramebuffer(GL_FRAMEBUFFER, _fbo);

    _pm->projectM_resetGL(width, height);

    // Reallocate pixel buffer
    _pixel_buffer.resize(width * height * 4);

    UtilityFunctions::print("ProjectMWrapper: viewport resized to ", width, "x", height);
}
