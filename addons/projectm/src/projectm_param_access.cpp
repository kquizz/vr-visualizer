/**
 * projectm_param_access.cpp — internal parameter access for projectM v4
 *
 * Uses #define private public to access internal projectM fields.
 * This is a well-known technique for instrumentation when building from source.
 * We control the build, so this is safe and practical.
 */
#include "projectm_param_access.h"

// Temporarily expose private members for internal access
#define private public
#define protected public

#include <ProjectMCWrapper.hpp>
#include <MilkdropPreset/MilkdropPreset.hpp>
#include <MilkdropPreset/PresetState.hpp>
#include <Preset.hpp>

#undef private
#undef protected

#include <cstring>

// Fully-qualified type aliases
using PM = libprojectM::ProjectM;
using PMWrapper = libprojectM::projectMWrapper;
using MDP = libprojectM::MilkdropPreset::MilkdropPreset;
using PState = libprojectM::MilkdropPreset::PresetState;
using Preset = libprojectM::Preset;

static MDP* get_active_milkdrop_preset(projectm_handle handle) {
    if (!handle) return nullptr;
    auto* wrapper = reinterpret_cast<PMWrapper*>(handle);
    auto& preset_ptr = wrapper->m_activePreset;
    if (!preset_ptr) return nullptr;
    return dynamic_cast<MDP*>(preset_ptr.get());
}

static PState* get_preset_state(projectm_handle handle) {
    auto* preset = get_active_milkdrop_preset(handle);
    if (!preset) return nullptr;
    return &preset->m_state;
}

// --- Parameter name → field offset mapping ---

struct ParamEntry {
    const char* name;
    size_t offset;
};

#define PARAM(field) { #field, offsetof(PState, field) }

static const ParamEntry s_params[] = {
    PARAM(zoom),
    PARAM(rot),
    PARAM(rotCX),
    PARAM(rotCY),
    PARAM(xPush),
    PARAM(yPush),
    PARAM(warpAmount),
    PARAM(stretchX),
    PARAM(stretchY),
    PARAM(decay),
    PARAM(waveR),
    PARAM(waveG),
    PARAM(waveB),
    PARAM(waveX),
    PARAM(waveY),
    PARAM(waveAlpha),
    PARAM(waveScale),
    PARAM(waveSmoothing),
    PARAM(warpScale),
    PARAM(zoomExponent),
    PARAM(gammaAdj),
    PARAM(videoEchoZoom),
    PARAM(videoEchoAlpha),
    PARAM(outerBorderSize),
    PARAM(outerBorderR),
    PARAM(outerBorderG),
    PARAM(outerBorderB),
    PARAM(outerBorderA),
    PARAM(innerBorderSize),
    PARAM(innerBorderR),
    PARAM(innerBorderG),
    PARAM(innerBorderB),
    PARAM(innerBorderA),
    PARAM(mvX),
    PARAM(mvY),
    PARAM(mvDX),
    PARAM(mvDY),
    PARAM(mvL),
    PARAM(mvR),
    PARAM(mvG),
    PARAM(mvB),
    PARAM(mvA),
    PARAM(shader),
    { nullptr, 0 }
};

#undef PARAM

static const ParamEntry* find_param(const char* name) {
    for (const ParamEntry* p = s_params; p->name; ++p) {
        if (strcmp(p->name, name) == 0) return p;
    }
    return nullptr;
}

// --- Public C API ---

extern "C" {

bool projectm_set_preset_param(projectm_handle instance, const char* name, float value) {
    auto* state = get_preset_state(instance);
    if (!state) return false;
    const auto* param = find_param(name);
    if (!param) return false;
    auto* field = reinterpret_cast<float*>(reinterpret_cast<char*>(state) + param->offset);
    *field = value;
    return true;
}

float projectm_get_preset_param(projectm_handle instance, const char* name) {
    auto* state = get_preset_state(instance);
    if (!state) return 0.0f;
    const auto* param = find_param(name);
    if (!param) return 0.0f;
    const auto* field = reinterpret_cast<const float*>(reinterpret_cast<const char*>(state) + param->offset);
    return *field;
}

bool projectm_set_q_variable(projectm_handle instance, int index, float value) {
    if (index < 1 || index > 32) return false;
    auto* state = get_preset_state(instance);
    if (!state) return false;
    state->frameQVariables[index - 1] = static_cast<double>(value);
    return true;
}

float projectm_get_q_variable(projectm_handle instance, int index) {
    if (index < 1 || index > 32) return 0.0f;
    auto* state = get_preset_state(instance);
    if (!state) return 0.0f;
    return static_cast<float>(state->frameQVariables[index - 1]);
}

} // extern "C"
