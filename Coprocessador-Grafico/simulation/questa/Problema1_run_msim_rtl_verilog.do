transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -vlog01compat -work work +incdir+C:/Users/felip/Downloads/Coprocessador_V3TESTE_corrigido\ (1)/Coprocessador_V1TESTE {C:/Users/felip/Downloads/Coprocessador_V3TESTE_corrigido (1)/Coprocessador_V1TESTE/DE1_SOC_golden_top.v}
vlog -vlog01compat -work work +incdir+C:/Users/felip/Downloads/Coprocessador_V3TESTE_corrigido\ (1)/Coprocessador_V1TESTE {C:/Users/felip/Downloads/Coprocessador_V3TESTE_corrigido (1)/Coprocessador_V1TESTE/vga_driver.v}
vlog -vlog01compat -work work +incdir+C:/Users/felip/Downloads/Coprocessador_V3TESTE_corrigido\ (1)/Coprocessador_V1TESTE {C:/Users/felip/Downloads/Coprocessador_V3TESTE_corrigido (1)/Coprocessador_V1TESTE/rasterizador_poligonos.v}
vlog -vlog01compat -work work +incdir+C:/Users/felip/Downloads/Coprocessador_V3TESTE_corrigido\ (1)/Coprocessador_V1TESTE {C:/Users/felip/Downloads/Coprocessador_V3TESTE_corrigido (1)/Coprocessador_V1TESTE/background_renderer.v}
vlog -vlog01compat -work work +incdir+C:/Users/felip/Downloads/Coprocessador_V3TESTE_corrigido\ (1)/Coprocessador_V1TESTE {C:/Users/felip/Downloads/Coprocessador_V3TESTE_corrigido (1)/Coprocessador_V1TESTE/motor_sprite.v}
vlog -vlog01compat -work work +incdir+C:/Users/felip/Downloads/Coprocessador_V3TESTE_corrigido\ (1)/Coprocessador_V1TESTE {C:/Users/felip/Downloads/Coprocessador_V3TESTE_corrigido (1)/Coprocessador_V1TESTE/top_coprocessador.v}
vlog -vlog01compat -work work +incdir+C:/Users/felip/Downloads/Coprocessador_V3TESTE_corrigido\ (1)/Coprocessador_V1TESTE {C:/Users/felip/Downloads/Coprocessador_V3TESTE_corrigido (1)/Coprocessador_V1TESTE/rom_memoria2.v}
vlog -vlog01compat -work work +incdir+C:/Users/felip/Downloads/Coprocessador_V3TESTE_corrigido\ (1)/Coprocessador_V1TESTE {C:/Users/felip/Downloads/Coprocessador_V3TESTE_corrigido (1)/Coprocessador_V1TESTE/unidade_de_controle.v}
vlog -vlog01compat -work work +incdir+C:/Users/felip/Downloads/Coprocessador_V3TESTE_corrigido\ (1)/Coprocessador_V1TESTE {C:/Users/felip/Downloads/Coprocessador_V3TESTE_corrigido (1)/Coprocessador_V1TESTE/ram_tilemap_2port.v}
vlog -vlog01compat -work work +incdir+C:/Users/felip/Downloads/Coprocessador_V3TESTE_corrigido\ (1)/Coprocessador_V1TESTE {C:/Users/felip/Downloads/Coprocessador_V3TESTE_corrigido (1)/Coprocessador_V1TESTE/ram_tile.v}
vlog -vlog01compat -work work +incdir+C:/Users/felip/Downloads/Coprocessador_V3TESTE_corrigido\ (1)/Coprocessador_V1TESTE {C:/Users/felip/Downloads/Coprocessador_V3TESTE_corrigido (1)/Coprocessador_V1TESTE/paleta_rom.v}

