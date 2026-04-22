#ifndef PROJECTM_WRAPPER_H
#define PROJECTM_WRAPPER_H

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>

#include <projectM-4/types.h>

namespace godot {

class ProjectMWrapper : public Node {
    GDCLASS(ProjectMWrapper, Node)

private:
    projectm_handle _pm = nullptr;
    bool _initialized = false;
    int _width = 512;
    int _height = 512;
    Ref<ImageTexture> _texture;
    PackedByteArray _pixel_buffer;

    // Platform-specific offscreen GL context
    void *_sdl_window = nullptr;   // SDL_Window* (hidden)
    void *_sdl_gl_context = nullptr; // SDL_GLContext

    // Our own FBO for projectM to render into
    unsigned int _fbo = 0;
    unsigned int _fbo_color_tex = 0;
    unsigned int _fbo_depth_rb = 0;
    int _debug_frame = 0;

    bool _create_gl_context();
    void _destroy_gl_context();
    void _make_gl_current();
    bool _create_fbo();
    void _destroy_fbo();

protected:
    static void _bind_methods();

public:
    ProjectMWrapper();
    ~ProjectMWrapper();

    // Core API exposed to GDScript
    bool initialize(int width, int height);
    void shutdown();
    bool is_initialized() const;

    // Preset management
    bool load_preset(const String &path);
    String get_preset_name() const;

    // Audio input (raw PCM float samples, interleaved stereo)
    void feed_audio(const PackedFloat32Array &samples);

    // Rendering
    void render_frame();
    Ref<ImageTexture> get_texture() const;

    // Configuration
    void set_viewport_size(int width, int height);

    // Runtime parameter control (v4 internal access)
    bool set_param(const String &name, float value);
    float get_param(const String &name) const;
    bool set_q_variable(int index, float value);
    float get_q_variable(int index) const;
};

} // namespace godot

#endif
