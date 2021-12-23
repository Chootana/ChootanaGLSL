@echo off 

copy  %1 shader.glsl
call Bonzomatic_W64_GLFW.exe 

copy shader.glsl %1
