#ifndef PROJECTM_WRAPPER_H
#define PROJECTM_WRAPPER_H

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>

// Forward declare projectM (avoid exposing internals to Godot headers)
class projectM;

namespace godot {

class ProjectMWrapper : public Node {
    GDCLASS(ProjectMWrapper, Node)

private:
    projectM *_pm = nullptr;
    bool _initialized = false;
    int _width = 512;
    int _height = 512;
    unsigned int _gl_texture_id = 0;
    Ref<ImageTexture> _texture;
    PackedByteArray _pixel_buffer;

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
};

} // namespace godot

#endif
