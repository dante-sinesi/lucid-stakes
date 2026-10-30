shader_type spatial;
render_mode blend_mix, cull_back;   // (las caras de adelante del cristal; las de atrás van aparte y se dibujan antes)

#include "res://shaders/voxel_cristal.gdshaderinc"
