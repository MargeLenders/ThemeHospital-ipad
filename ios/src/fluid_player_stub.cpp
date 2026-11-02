/*
  iOS fluid_player stub for CorsixTH.
  Isolates iOS audio synthesis until Phase 5.
*/

#include "../../CorsixTH/Src/fluid_player.h"

fluid_player::fluid_player(const std::string& soundfont)
    : settings(nullptr),
      synth(nullptr),
      player(nullptr),
      soundfont_id(0),
      audio_stream(nullptr) {
  (void)soundfont;
}

fluid_player::~fluid_player() = default;

void fluid_player::set_volume(double volume) {
  (void)volume;
}

void fluid_player::play_xmi(const unsigned char* xmi_data, size_t xmi_length) {
  (void)xmi_data;
  (void)xmi_length;
}

void fluid_player::stop() {}

void fluid_player::pause() {}

void fluid_player::resume() {}

void fluid_player::audio_stream_callback(void* userdata, SDL_AudioStream* stream,
                                         int additional_amount, int total_amount) {
  (void)userdata;
  (void)stream;
  (void)additional_amount;
  (void)total_amount;
}
