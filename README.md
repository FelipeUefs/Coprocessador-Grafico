# Projeto Coprocessador Gráfico em FPGA (Problema #1)

**Universidade Estadual de Feira de Santana (UEFS)**
**Departamento de Tecnologia - Área de Eletrônica** 
**Disciplina: Sistemas Digitais (TEC499) - 2026.2 **
**Autores: Felipe Gomes, Mirela Mascarenhas e Caio Bruno**
Para a elaboração do projeto, foi utilizado o kit de desenvolvimento DE1-SoC com o processador Cyclone V, permitindo a leitura e escrita de dados diretamente na memória RAM do dispositivo, o ambiente de desenvolvimento utilizado foi o Quartus Lite na versão 23.1 e para linguagem de descrição de hardware foi lidado com Verilog. O Objetivo deste projeto é projetar  o núcleo de um coprocessador gráfico em FPGA. O hardware foi desenvolvido visando a arquitetura de consoles clássicos de 16 bits, operando com suporte a um plano de fundo (baseado em tiles), sprite móvel e um rasterizador de polígonos. O coprocessador funciona de modo isolado nesta primeira fase, mas está preparado para integração via Memory-Mapped I/O (MMIO) com um driver Linux em Assembly (processador ARM) e uma aplicação em C em etapas futuras.

