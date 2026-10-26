shader_type spatial;
render_mode blend_mix, cull_back;   // (las caras de adelante del hielo; las de atrás van aparte, en voxel_hielo_atras.gdshader, y se dibujan antes: así el cristal no cambia al girar la cámara)

#include "res://shaders/voxel_hielo.gdshaderinc"
