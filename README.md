# Projeto Coprocessador Gráfico em FPGA (Problema #1)

**Universidade Estadual de Feira de Santana (UEFS)**  
**Departamento de Tecnologia - Área de Eletrônica**  
**Disciplina: Sistemas Digitais (TEC499) - 2026.2**  
**Autores: Felipe Gomes, Mirela Mascarenhas e Caio Bruno**

Para a elaboração do projeto, foi utilizado o kit de desenvolvimento DE1-SoC com o processador Cyclone V, permitindo a leitura e escrita de dados diretamente na memória RAM do dispositivo. O ambiente de desenvolvimento utilizado foi o Quartus Lite na versão 23.1 e, para a linguagem de descrição de hardware, foi utilizado Verilog. 

O objetivo deste projeto é projetar o núcleo de um coprocessador gráfico em FPGA. O hardware foi desenvolvido visando a arquitetura de consoles clássicos de 16 bits, operando com suporte a um plano de fundo (baseado em tiles), sprite móvel e um rasterizador de polígonos. O coprocessador funciona de modo isolado nesta primeira fase, mas está preparado para integração via Memory-Mapped I/O (MMIO) com um driver Linux em Assembly (processador ARM) e uma aplicação em C em etapas futuras.

<img width="600" alt="Placa DE1-SoC" src="https://github.com/user-attachments/assets/4e606e05-cef6-4a21-8f5b-80f50d49108b" />
*Imagem da placa DE1-SoC retirada do site da Altera*

---

## Sumário

1. Levantamento de Requisitos 
2. Softwares Utilizados
3. Hardware Usado nos Testes
4. Arquitetura do Sistema
5. Instalação e Configuração
6. Teste de Funcionamento
7. Análise dos Resultados

---

## 1. Levantamento de Requisitos

### 1.1 Requisitos Funcionais

* **RF01:** O sistema deve armazenar dados gráficos em memórias internas e receber comandos de 32 bits.
* **RF02:** O sinal de vídeo para a tela deve ser gerado continuamente.
* **RF03:** É necessário que o projeto gerencie um plano de fundo contendo um mapa de tiles de 40x30 posições.
* **RF04:** O sistema deve ser capaz de realizar o deslocamento vertical e horizontal da cena e permitir a atualização do tile em cada posição.
* **RF05:** No mínimo 256 padrões de tiles, de 8x8 pixels, devem estar disponíveis na memória interna.
* **RF06:** Deve ser disponibilizada memória de atributos para gerenciar no mínimo 32 sprites de 16x16 pixels.
* **RF07:** O sistema deve permitir a configuração de parâmetros para cada sprite: habilitação, espelhamento, posição X e Y, prioridade, índice do padrão e paleta.
* **RF08:** Retângulos preenchidos e triângulos devem ser rasterizados como primitivas geométricas.
* **RF09:** O projeto deve garantir a aplicação de transparência com o índice de cor 0 durante a combinação pixel a pixel das camadas de background, polígonos e sprites.
* **RF10:** A composição das camadas visuais deve incluir a aplicação de pelo menos três níveis de prioridade.
* **RF11:** Utilizando uma paleta programável de 256 cores, o sistema deve converter os índices de 8 bits em sinal RGB.

### 1.2 Requisitos Não Funcionais

* **RNF01:** Linguagem Verilog deve ser usada para codificar o núcleo completo do coprocessador.
* **RNF02:** As unidades de saída, memórias, datapath, controle e motores gráficos devem estar separados na arquitetura interna.
* **RNF03:** A resolução de 320x240 pixels é a única permitida para o jogo.
* **RNF04:** A interface VGA da placa DE1-SoC deve ser utilizada para a saída física de vídeo, operando a aproximadamente 60 Hz e com resolução de 640x480 pixels.
* **RNF05:** Em hardware, os pixels lógicos devem sofrer ampliação de 2x2.
* **RNF06:** É necessário que exista uma estratégia definida para inicializar e reinicializar todos os registradores e módulos de memória.
* **RNF07:** Após a inicialização, o sinal gerado não deve ter falhas de sincronismo, pixels indefinidos ou instabilidade visual.
* **RNF08:** Os cálculos no rasterizador de polígonos devem ser restritos à aritmética inteira.
* **RNF09:** Chaves, LEDs e botões da placa DE1-SoC só podem ser usados para demonstração do núcleo e não devem substituir a futura comunicação via MMIO.

---

## 2. Softwares Utilizados

* **IDE de Desenvolvimento:** Intel Quartus Prime Lite Edition (23.1std.0)
* **Simulador:** ModelSim - Intel FPGA Edition (2020.1)
* **Linguagem HDL:** Verilog-2001

---

## 3. Hardware Usado nos Testes

* Kit de Desenvolvimento Terasic DE1-SoC
* FPGA Intel Cyclone V (5CSEMA5F31C6)
* Processador HPS ARM Cortex-A9 Dual-Core (800 MHz)
* Monitor Philips VGA 640×480 @ ~60 Hz

---

## 4. Arquitetura do Sistema

### 4.1 Descrição dos Módulos

* **`top_coprocessador.v` — Módulo Raiz:** 
  Instancia e interliga todos os componentes. Realiza a divisão de clock de 50 MHz para 25 MHz (necessário para VGA 640x480), mapeia as coordenadas físicas (`vga_x`, `vga_y`) para coordenadas lógicas (`logical_x`, `logical_y`) via deslocamento de 1 bit (escala 2x2), e implementa o compositor de camadas com prioridade fixa: *sprite > polígono > background > cor de fundo*.

* **`vga_driver.v` — Gerador de Sinal VGA:** 
  Gera os sinais de sincronismo horizontal (HSYNC) e vertical (VSYNC) de acordo com o padrão VGA 640×480 @ 60 Hz com pixel clock de 25 MHz. Implementado como uma máquina de estados com 4 estados por eixo (ACTIVE, FRONT PORCH, SYNC PULSE, BACK PORCH). Emite as coordenadas do próximo pixel a ser desenhado (`next_x`, `next_y`) antecipadamente para que os motores gráficos processem o pixel com latência de pipeline.

| Parâmetro | Horizontal | Vertical |
| :--- | :--- | :--- |
| **Pixels Ativos** | 640 | 480 |
| **Front porch** | 16 | 10 |
| **Sync pulse** | 96 | 2 |
| **Back porch** | 48 | 33 |

* **`background_renderer.v` — Motor de Background (Tilemap):** 
  Renderiza o plano de fundo baseado em um mapa de tiles de **40×30 posições**, onde cada tile tem **8×8 pixels** (totalizando 320×240 pixels lógicos). Suporta **scroll horizontal e vertical** com wrap-around: ao ultrapassar os limites da tela lógica, a posição retorna ao início, criando rolagem contínua. O acesso às memórias exige um ciclo de latência de pipeline — os registros `row_d1` e `col_d1` compensam esse atraso para que o endereço da ROM de pixel aponte para o tile correto.

* **`motor_sprite.v` — Motor de Sprites:** 
  Gerencia até **32 sprites simultâneos** de **16×16 pixels** usando uma OAM (Object Attribute Memory) local. Cada sprite possui: posição X/Y, índice de tile base, habilitação, espelhamento horizontal e vertical. A detecção de hit é feita por varredura paralela combinacional (todos os 32 slots testados a cada pixel). O sprite de índice 0 tem maior prioridade. O sprite 16×16 é composto por 4 sub-tiles de 8×8, e o espelhamento inverte o deslocamento efetivo (dx, dy), reordenando automaticamente os quadrantes.

* **`rasterizador_poligonos.v` — Rasterizador de Polígonos:** 
  Implementa rasterização por varredura para **retângulos** e **triângulos** usando aritmética inteira pura. Para o retângulo, a detecção é feita por comparação direta das coordenadas com os limites `(x0,y0)-(x1,y1)`. Para o triângulo, utiliza o método das **funções de aresta**: um pixel está dentro do triângulo se estiver do mesmo lado (todos positivos = CCW, ou todos negativos = CW) das três arestas, calculado via produto vetorial 2D.

* **`unidade_de_controle.v` — Unidade de Controle (FSM):** 
  Máquina de estados que interpreta os botões e chaves da placa para controlar a cena em tempo de execução. As atualizações só ocorrem no pulso `fim_de_quadro` (gerado ao final de cada frame), garantindo que mudanças de posição/scroll aconteçam entre frames sem rasgo de imagem. O botão `KEY1` cicla entre 5 estados de operação.

| Estado | Função das Chaves SW |
| :--- | :--- |
| **STATE_SCROLL** | Movimenta o scroll do background (direita/esquerda/cima/baixo). |
| **STATE_SPRITE** | Move o sprite 0 com clamping nas bordas e controla o espelhamento. |
| **STATE_RECT_COLOR** | Seleciona a cor do retângulo via `SW[3:0]`. |
| **STATE_TRI_COLOR** | Seleciona a cor do triângulo via `SW[3:0]`. |
| **STATE_TILE_EDIT** | Habilita a gravação e troca do Tile 2x2 do background ao acionar `SW[7]`. |

* **`paleta_rom.v` — ROM de Paleta (256 cores):** 
  Converte índices de 8 bits em componentes RGB de 24 bits (8 bits por canal) usando uma ROM inicializada pelo arquivo `paleta.mif`. A paleta pode ser substituída para alterar o esquema de cores do sistema inteiro sem modificar os motores gráficos.

### 4.2 Memórias Utilizadas

| Módulo | Arquivo MIF | Tamanho | Conteúdo |
| :--- | :--- | :--- | :--- |
| **ram_tile** | `tile_back.mif` | 256 tiles × 64 px = 16.384 entradas de 8 bits | Padrões de pixel do tileset de background |
| **ram_tilemap_2port** | `tilemap_back.mif` | 64x32 = 2.048 entradas de 8 bits | Mapa de tiles da cena |
| **rom_memoria2** | `espace_invasor.mif` | 256 tiles × 64 px = 16.384 entradas de 8 bits | Padrões de pixel dos sprites |
| **paleta_rom** | `paleta.mif` | 256 entradas de 24 bits | Tabela de cores RGB |

### 4.3 Sistema de Prioridade e Transparência

A composição das camadas segue a prioridade: **Sprite > Polígono > Background > Cor de Fundo**. O índice de cor `0` é tratado como transparência em todas as camadas — se a camada de maior prioridade retornar índice 0, a próxima camada na hierarquia é exibida.

```verilog
    wire [7:0] final_pixel_index =
        (spr_active && spr_color != 8'd0)   ? spr_color  :
        (poly_active && poly_color != 8'd0) ? poly_color :
        (bkg_color != 8'd0)                 ? bkg_color  :
                                              cor_de_fundo;
```
### 4.4 Utilização de Recursos (Síntese - Cyclone V)

| Recurso | Utilizado | Disponível | Percentual |
| :--- | :--- | :--- | :--- |
| **ALMs (Lógica)** | 218 | 32.070 | < 1% |
| **Registradores** | 157 | — | — |
| **Blocos de RAM** | 23 | 397 | 6% |
| **Bits de memória** | 186.368 | 4.065.280 | 5% |
| **Blocos DSP** | 6 | 87 | 7% |
| **Pinos** | 241 | 457 | 53% |

---

## 5. Instalação e Configuração

Para compilar e gravar o projeto na DE1-SoC:

1. Clone este repositório para a sua máquina local.
2. Abra o Intel Quartus Prime Lite Edition.
3. Vá em **File > Open Project** e selecione o arquivo do projeto `.qpf`.
4. Certifique-se de que os arquivos `.mif` (Memória de Inicialização) estão no mesmo diretório do projeto ou mapeados corretamente nos módulos MegaWizard/IP Catalog.
5. Clique em **Compile Design** e aguarde a finalização.
6. Conecte a DE1-SoC ao computador via USB-Blaster e ligue a placa.
7. Vá em **Tools > Programmer**.
8. Selecione o arquivo `.sof` gerado na pasta `output_files`.
9. Clique em **Start** para gravar o bitstream na FPGA.

---

## 6. Teste e Funcionamento

Após gravar o bitstream na placa, o sistema exibirá no monitor o background via Tilemap e o sprite centralizado.

### Demonstração do Sistema
<!-- Substitua o link abaixo pela sua imagem, GIF ou vídeo gravado na bancada -->
![Demonstração do Sistema](link-do-seu-video-ou-gif-aqui)

### Controles de Demonstração (Botões - KEY)

| Botão | Função |
| :--- | :--- |
| **KEY0** | Reset geral - reinicia todos os módulos ao estado inicial. |
| **KEY1** | Alterna entre os modos de controle (Scroll → Sprite → Cor Retângulo → Cor Triângulo → Tile Swap). |
| **KEY2** | Liga/Desliga a exibição do retângulo geométrico. |
| **KEY3** | Liga/Desliga a exibição do triângulo geométrico. |

### Controles de Demonstração (Chaves - SW)
As chaves de 0 a 3 assumem funções diferentes dependendo do modo ativado pela `KEY1`.

| Chave | Modo Scroll | Modo Sprite | Modo Cores |
| :--- | :--- | :--- | :--- |
| **SW[0]** | Scroll Direita | Move sprite Direita | Ajuste de Cor (Bit 0) |
| **SW[1]** | Scroll Esquerda | Move sprite Esquerda | Ajuste de Cor (Bit 1) |
| **SW[2]** | Scroll Baixo | Move sprite Baixo | Ajuste de Cor (Bit 2) |
| **SW[3]** | Scroll Cima | Move sprite Cima | Ajuste de Cor (Bit 3) |
| **SW[8]** | – | Espelha sprite horizontalmente | – |
| **SW[9]** | – | Espelha sprite verticalmente | – |

* **Modo Tile Swap:** Quando o sistema atinge o último estado na `KEY1`, a chave **SW[7]** se torna um gatilho para a escrita na RAM, permitindo trocar dinamicamente o tile do canto pelo do centro da tela.

### Sequência de Teste Sugerida

1. Energize a placa e observe a cena inicial: background com tilemap e o sprite da nave centralizado.
2. Mova as chaves `SW[0..3]` para verificar o scroll do background com wrap-around funcional.
3. Pressione `KEY1` para mudar para o modo sprite e use as mesmas chaves para mover a nave.
4. Ative `SW[8]` e `SW[9]` para verificar o espelhamento horizontal e vertical da nave.
5. Pressione `KEY2` para exibir o retângulo e `KEY3` para exibir o triângulo.
6. Pressione `KEY1` para os modos de cor e altere `SW[0..3]` para observar a mudança de cores dos polígonos.
7. Pressione `KEY1` para acessar o modo de Edição de Tile e alterne `SW[7]` para ver a troca de um bloco 2x2 do background em tempo real.
8. Pressione `KEY0` para confirmar que o reset retorna a cena ao estado inicial.

---

## 7. Análise dos Resultados

O coprocessador gráfico foi implementado com sucesso na FPGA Cyclone V da placa DE1-SoC, atendendo aos principais requisitos funcionais e não funcionais do escopo da Fase 1.

### Resultados Alcançados

* **Saída VGA estável:** O sinal de vídeo é gerado continuamente em 640×480 @ 60 Hz sem falhas de sincronismo, utilizando um pixel clock de 25 MHz obtido pela divisão do clock de 50 MHz da placa.
* **Background com scroll:** O mapa de tiles de 40×30 posições é renderizado corretamente com suporte a deslocamento horizontal e vertical contínuo com wrap-around.
* **Sistema de sprites funcional:** O motor de sprites gerencia entidades com suporte a espelhamento horizontal e vertical por inversão combinacional de coordenadas. O pipeline de 1 ciclo de clock para leitura da ROM é compensado para evitar atrasos na tela.
* **Rasterização de polígonos:** Retângulos e triângulos são rasterizados por varredura com aritmética inteira, sem ponto flutuante, respeitando os limites de recursos e as premissas de projeto.
* **Composição de camadas e transparência:** O sistema de prioridade de 3 níveis (Sprite > Polígono > Background) funciona conforme projetado, com o índice de cor `0` atuando como chave de transparência (Alpha) em todas as camadas.
* **Utilização de recursos eficiente:** O projeto utiliza menos de 1% da lógica combinacional disponível (218 de 32.070 ALMs), 6% dos blocos de RAM e 7% dos blocos DSP, deixando ampla margem para integração com o driver ARM.

### Limitações e Trabalhos Futuros

* Os parâmetros geométricos base dos polígonos e grande parte da OAM dos sprites estão fixados no Hardware. A integração via MMIO permitirá que o código em C os configure dinamicamente.
* A troca simultânea de buffers (Double Buffering) será implementada na Fase 2 para garantir transições assíncronas suaves sob o comando do ARM.
* Efeitos avançados de mistura de cores (*color blending* para transparências parciais) não foram implementados nesta fase para poupar o limite de processamento de ALMs.

