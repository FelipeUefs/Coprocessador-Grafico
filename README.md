**Universidade Estadual de Feira de Santana (UEFS)**  
**Departamento de Tecnologia - Área de Eletrônica**  
**Disciplina: Sistemas Digitais (TEC499) - 2026.2**  
**Autores: Felipe Gomes, Mirela Mascarenhas e Caio Bruno**

Para a elaboração do projeto, foi utilizado o kit de desenvolvimento DE1-SoC com o processador Cyclone V, permitindo a leitura e escrita de dados diretamente na memória RAM do dispositivo. O ambiente de desenvolvimento utilizado foi o Quartus Lite na versão 23.1 e, para a linguagem de descrição de hardware, foi utilizado Verilog. 

O objetivo deste projeto é projetar o núcleo de um coprocessador gráfico em FPGA. O hardware foi desenvolvido visando a arquitetura de consoles clássicos de 16 bits, operando com suporte a um plano de fundo (baseado em tiles), sprite móvel e um rasterizador de polígonos. O coprocessador funciona de modo isolado nesta primeira fase, mas está preparado para integração via Memory-Mapped I/O (MMIO) com um driver Linux em Assembly (processador ARM) e uma aplicação em C em etapas futuras.

<img width="600" alt="Placa DE1-SoC" src="https://github.com/user-attachments/assets/4e606e05-cef6-4a21-8f5b-80f50d49108b" />

Imagem da placa DE1-SoC retirada do site da Altera

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

Esta subseção apresenta o passo a passo para realizar a compilação do projeto utilizando o Intel Quartus Prime. Inicialmente, serão descritos os procedimentos necessários para a execução da compilação e, em seguida, serão apresentadas imagens ilustrativas com o objetivo de facilitar a compreensão e tornar o processo mais intuitivo.

Para compilar e gravar o projeto na DE1-SoC:

1. Clone este repositório para a sua máquina local.
2. Abra o Intel Quartus Prime Lite Edition.
3. Vá em **File > Open Project** e selecione o arquivo do projeto `Problema1.qpf`.
4. Certifique-se de que os arquivos `.mif` (Memória de Inicialização) estão no mesmo diretório do projeto ou mapeados corretamente nos módulos MegaWizard/IP Catalog.
5. Clique em **Start Compilation** e aguarde a finalização.
> **Nota:**
> Não é necessário gerar novas memórias nem  realizar a atribuição de pinos caso todos os arquivos do projeto tenham sido baixados, pois os arquivos de memória necessários e a atribuição de pinos já estão previamente gerados e incluídos no projeto.

 A compilação será finalizada quando a barra de progresso atingir **100%** e for exibida a mensagem **"Successful"**, indicando que o projeto foi compilado com sucesso.
 
**Programação da FPGA**
Após a compilação bem-sucedida.
1. Conecte a DE1-SoC ao computador via USB-Blaster e ligue a placa.
2. Vá em **Tools > Programmer**.
3. Clique em **Start** para gravar o bitstream na FPGA.

As imagens abaixo ilustram o processo

<img width="1600" height="900" alt="WhatsApp Image 2026-09-07 at 18 43 58" src="https://github.com/user-attachments/assets/49137a7c-ca8c-4604-84b7-0d52ed207c35" />
<img width="1600" height="900" alt="WhatsApp Image 2026-09-07 at 18 47 13" src="https://github.com/user-attachments/assets/e320263c-f143-45aa-b99c-becf88d4693a" />
<img width="1600" height="900" alt="WhatsApp Image 2026-09-07 at 19 56 12" src="https://github.com/user-attachments/assets/0fcefeb7-2430-42a2-b3cb-03ec20200c26" />
<img width="1600" height="900" alt="WhatsApp Image 2026-09-07 at 18 50 04" src="https://github.com/user-attachments/assets/f0ef902c-9ee5-4635-97d6-f24166dad4ce" />
<img width="1600" height="900" alt="WhatsApp Image 2026-09-07 at 18 51 45" src="https://github.com/user-attachments/assets/7d6f849b-ebe8-4375-abeb-fae1f682e1bc" />




---

## 6. Teste e Funcionamento

Após gravar o bitstream na placa, o sistema exibirá no monitor o background via Tilemap e o sprite centralizado.

<img width="795" height="502" alt="WhatsApp Image 2026-09-07 at 19 52 20" src="https://github.com/user-attachments/assets/113fffc9-1d08-45f5-ae47-3696976cbf77" />


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

### Sequência de Teste Sugerida

1. Energize a placa e observe a cena inicial: background com tilemap e o sprite da nave centralizado.  <img width="3264" height="2448" alt="SGCAM_20260902_092907052 MP" src="https://github.com/user-attachments/assets/390e5f03-8cfe-457e-869b-f492c9d41af9" />
2. Mova as chaves `SW[0..3]` para verificar o scroll do background com wrap-around funcional. <img width="384" height="216" alt="SGCAM_20260902_093009737" src="https://github.com/user-attachments/assets/9f5a8f7d-b364-48c3-943b-e4a815040471" /> <img width="384" height="216" alt="SGCAM_20260902_093009737 (2)" src="https://github.com/user-attachments/assets/d4d4b2e5-0c6a-40e5-a64d-1ea9db4001ad" /> <img width="384" height="216" alt="SGCAM_20260902_093009737 (3)" src="https://github.com/user-attachments/assets/badf1b54-5742-47ce-9b87-d65b14be13a1" /> <img width="384" height="216" alt="SGCAM_20260902_093009737 (4)" src="https://github.com/user-attachments/assets/1efc69b7-b6e1-4093-b675-be5f4347c210" />
3. Pressione `KEY1` para mudar para o modo sprite e use as mesmas chaves para mover a nave. <img width="384" height="216" alt="SGCAM_20260902_093009737 (5)" src="https://github.com/user-attachments/assets/d8065e6d-f914-45a7-a21f-4cb72b4eab75" />
4. Ative `SW[8]` e `SW[9]` para verificar o espelhamento horizontal e vertical da nave.  <img width="3264" height="2448" alt="SGCAM_20260902_092947733 MP" src="https://github.com/user-attachments/assets/2061836e-f09f-44c8-988b-37208b54cec9" /> <img width="3264" height="2448" alt="SGCAM_20260902_092955197 MP (1)" src="https://github.com/user-attachments/assets/d941a21a-e087-49c5-b569-706ee01f0f73" />
5. Pressione `KEY2` para exibir/esconder o retângulo e `KEY3` para exibir/esconder o triângulo. <img width="3264" height="2448" alt="SGCAM_20260902_093603365 MP" src="https://github.com/user-attachments/assets/f0444aa5-426b-430d-8ea5-bdfdabdbe087" /> <img width="3264" height="2448" alt="SGCAM_20260902_093611426 MP" src="https://github.com/user-attachments/assets/c0a237f3-83b0-40c3-8de1-7ea2d6ff0927" />
6. Pressione `KEY1` para os modos de cor e altere `SW[0..3]` para observar a mudança de cores dos polígonos. <img width="3264" height="2448" alt="SGCAM_20260902_093745579 MP" src="https://github.com/user-attachments/assets/399d10c5-6bf9-4dfe-9dc6-98ea08371314" />
7. Pressione `KEY0` para confirmar que o reset retorna a cena ao estado inicial.

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

### Referências

ADAMS, V. Hunter. *VGA Driver in Verilog*. [S. l.], [s. d.]. Disponível em: https://vanhunteradams.com/DE1/VGA_Driver/Driver.html. Acesso em: 24 ago. 2026.

PATTERSON, David A.; HENNESSY, John L. *Computer Organization and Design: The Hardware/Software Interface, ARM Edition*. [S. l.]: Morgan Kaufmann, 2016. (The Morgan Kaufmann Series in Computer Architecture and Design).


