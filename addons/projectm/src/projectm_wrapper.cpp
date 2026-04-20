#include "projectm_wrapper.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <libprojectM/projectM.hpp>

#ifdef __APPLE__
#define GL_SILENCE_DEPRECATION
#include <OpenGL/gl.h>
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

bool ProjectMWrapper::initialize(int width, int height) {
    if (_initialized) {
        WARN_PRINT("ProjectMWrapper: already initialized, call shutdown() first");
        return false;
    }

    _width = width;
    _height = height;

    // Configure projectM v3 settings
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

    _pm = new projectM(settings, projectM::FLAG_DISABLE_PLAYLIST_LOAD);

    if (!_pm) {
        ERR_PRINT("ProjectMWrapper: failed to create projectM instance");
        return false;
    }

    // Initialize render-to-texture (returns GL texture id)
    _gl_texture_id = _pm->initRenderToTexture();

    // Allocate pixel readback buffer (RGBA)
    _pixel_buffer.resize(width * height * 4);

    // Create ImageTexture placeholder
    Ref<Image> img = Image::create(width, height, false, Image::FORMAT_RGBA8);
    _texture.instantiate();
    _texture->set_image(img);

    _initialized = true;
    UtilityFunctions::print("ProjectMWrapper: initialized (", width, "x", height, ")");
    return true;
}

void ProjectMWrapper::shutdown() {
    if (_pm) {
        delete _pm;
        _pm = nullptr;
    }
    _initialized = false;
    _gl_texture_id = 0;
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

    // projectM renders to current GL context
    _pm->renderFrame();

    // Read back pixels from the GL texture into our buffer
    // Bind the projectM texture and read pixels
    if (_gl_texture_id > 0) {
        glBindTexture(GL_TEXTURE_2D, _gl_texture_id);
        glGetTexImage(GL_TEXTURE_2D, 0, GL_RGBA, GL_UNSIGNED_BYTE, _pixel_buffer.ptrw());
        glBindTexture(GL_TEXTURE_2D, 0);
    }

    // Create Godot Image from pixel buffer and update texture
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

    _width = width;
    _height = height;

    _pm->projectM_resetGL(width, height);

    // Reallocate pixel buffer
    _pixel_buffer.resize(width * height * 4);

    UtilityFunctions::print("ProjectMWrapper: viewport resized to ", width, "x", height);
}
