shader_type spatial;
render_mode blend_mix, cull_front;   // (las caras de atrás del hielo, que se ven a través del cristal; se dibujan antes que las de adelante)

#include "res://shaders/voxel_hielo.gdshaderinc"
