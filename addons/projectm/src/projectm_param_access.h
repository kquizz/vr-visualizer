/**
 * projectm_param_access.h — internal parameter access shim for projectM v4
 *
 * Built against projectM source (not just public headers) to access
 * PresetState fields for runtime parameter override.
 */
#pragma once

#include <projectM-4/types.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Set a named preset parameter (zoom, rot, decay, warp, wave_r, etc.)
 * Applied as an override on top of the preset's per-frame equation output.
 * Returns true if the parameter name was recognized.
 */
bool projectm_set_preset_param(projectm_handle instance, const char* name, float value);

/**
 * Get a named preset parameter's current value.
 * Returns 0.0 if not found.
 */
float projectm_get_preset_param(projectm_handle instance, const char* name);

/**
 * Set a q-variable (q1-q32) on the active preset.
 * Index is 1-based (q1=1, q32=32).
 */
bool projectm_set_q_variable(projectm_handle instance, int index, float value);

/**
 * Get a q-variable value. Index is 1-based.
 */
float projectm_get_q_variable(projectm_handle instance, int index);

#ifdef __cplusplus
}
#endif
