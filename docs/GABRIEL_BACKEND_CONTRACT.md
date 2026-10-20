# RAIN-V — backend 4-wide de Gabriel: contrato de integracao

## Requisito confirmado

**A memoria de dados deve aceitar quatro loads/stores no mesmo ciclo**, em qualquer combinacao (4L, 4S, 2L+2S...), inclusive quatro acessos ao mesmo endereco. Esta e a exigencia arquitetural desta entrega. O modelo anterior 4→1 nao atende ao requisito e foi substituido por **4→4 + RAM 4 portas**.

## Base e compatibilidade

- O snapshot `rain-v-revisao.zip` tem `central_processing_unit.v` como **somente front-end**; nao ha ainda pipeline EX/MEM/WB funcional. Este pacote nao simula uma CPU RV32I completa.
- `memory.v` original e `tests/memory_tb.v` permanecem compativeis, inclusive o acesso hierarquico `dut.mem`. Essa memoria legado 1-port NAO deve ser instanciada no backend 4-wide.
- `memory_byte_enabled.v` 1-port anterior permanece disponivel apenas para manter seus testes locais. No backend 4-wide, instanciar **somente** `memory_subsystem_4wide.v`, que encapsula quatro LSUs, distribuidor e a unica RAM logica `memory_4wide.v`.
- Todos os sinais vetorizados tem lane 0 nos bits menos significativos; lane 0 = instrucao mais antiga; lane 3 = mais jovem.

## Contrato dos modulos

| Modulo | Papel / interface |
| --- | --- |
| `register_bank.v` | 8 leituras assincronas (`read_addresses[39:0]`,`read_data[255:0]`), 4 escritas sincronas (`write_enable[3:0]`,`write_addresses[19:0]`,`write_data[127:0]`). `x0` fixo em 0. WAW vence mais nova. |
| `load_store_unit.v` | 1 instancia por lane: endian little; LD/ST RV32I, deslocamentos e mascaras de bytes; desalinhamento e `funct3` invalido bloqueiam a requisicao. |
| `memory_arbiter.v` | Distribuidor **4→4** combinacional: `grant=request_valid`, `stalled_requests=0`, `issue_allow_mask=1111`; repassa 4 enderecos, 4 words, mascaras e write flags. Nao arbitra conflitos de dado: memoria resolve. |
| `memory_4wide.v` | Unica RAM fisicamente modelada com 4R/4W logicas no mesmo ciclo. Endereco ALINHADO em bytes; 256 words = 1 KiB default, parametrizavel. Entradas `request_valid[3:0]`, `write_enable[3:0]`, `address[127:0]`, `write_data[127:0]`, `byte_enable[15:0]`. Saidas `read_data[127:0]`, `address_valid[3:0]`. |
| `memory_subsystem_4wide.v` | Topo recomendado para conexao ao pipeline. Entradas `clk`, `lane_valid[3:0]`, `mem_read[3:0]`, `mem_write[3:0]`, `effective_address[127:0]`, `store_data[127:0]`, `funct3[11:0]`. Saidas `load_result[127:0]`, `request_grant[3:0]`, `memory_valid[3:0]`, `load_valid[3:0]`, `misaligned[3:0]`, `illegal_op[3:0]`, `out_of_range[3:0]`. |
| `writeback_unit.v` | Seleciona ate 4 resultados em paralelo com `wb_sel`: `00` ALU, `01` MEM, `10` PC+4, `11` U (LUI). Gera 4 portas para banco de registradores. |

## Semantica para conflitos simultaneos

A RAM assume que o grupo de ate quatro instrucoes **ja foi validado e ordenado** pela Issue Unit. As operacoes memoria dentro de cada grupo tem efeito sequencial **na ordem das lanes**, mas todas completam no mesmo ciclo de memoria:

- **4 enderecos diferentes**: quatro stores ou quatro loads sao processados no mesmo ciclo.
- **4 loads para a mesma word**: os quatro recebem dados sem precisar de ciclos extras.
- **Stores na mesma word, bytes diferentes**: mascaras sao combinadas por byte.
- **Stores no mesmo byte**: vence a escrita da lane mais jovem (maior numero).
- **Store→load dentro do ciclo**: um load ve imediatamente (bypass combinacional) as stores de lanes **mais antigas** que tocavam aquele byte; nao ve stores futuras. Isso preserva a ordem do programa para memoria no grupo.
- **Load→store**: o load antigo observa o estado anterior a store mais jovem.
- **Falha de acesso na lane i**: o proprio acesso invalido nao escreve; todas as lanes **mais jovens** sao bloqueadas, para evitar stores posteriores a uma excecao da mesma janela. A Issue Unit deve tratar a falha da primeira instrucao em erro e reter/anular as restantes.

### Exemplo concreto

Suponha a palavra `M[0x10] = 0x11223344` no inicio do ciclo:

| Lane | Operacao | Resultado |
| --- | --- | --- |
| 0 | `SB 0xAA, 0x10` | Escreve byte 0 = AA |
| 1 | `LW 0x10` | Le `0x112233AA` no mesmo ciclo |
| 2 | `SB 0xBB, 0x11` | Escreve byte 1 = BB |
| 3 | `LW 0x10` | Le `0x1122BBAA` no mesmo ciclo |

Apos a borda de subida, `M[0x10] = 0x1122BBAA`.

## Integracao com Joao e Dielson

1. A interface `central_processing_unit.v` atual ja fornece `decoded_mem_read`, `decoded_mem_write`, `decoded_instructions`, `decoded_rs1`, `decoded_rs2`, `decoded_immediate`, `decoded_wb_sel` e outras por lane; **nao** liga-los diretamente a RAM como sinal de commit.
2. A ALU de execucao calcula `effective_address=rs1+immediate` (em **bytes**, nao endereco de palavra) para cada load/store emitido.
3. `funct3` = `decoded_instructions[i*32+12 +: 3]`; `mem_read` e `mem_write` correspondem aos controles da instrucao que realmente ocupa a lane do estagio MEM.
4. `lane_valid` deve conter somente instrucao aceita pela issue e nao anulada por stall/flush. Cada operacao deve acompanhar seus metadados (`rd`, PC, `wb_sel`, idade) ate MEM/WB.
5. `load_valid` marca quando `load_result` eh valido no estagio MEM. O controller deve registrar os resultados no ciclo correto para writeback. `memory_valid` = acesso legal dentro da capacidade da RAM. `misaligned`, `illegal_op`, `out_of_range` exigem politica de exception/trap; estas lanes NAO devem fazer commit nem usar o dado retornado.
6. O modulo comportamental resolve hazards **de memoria dentro de um grupo** (read-after-store, same-word). **RAW de registradores** e dependencia de resultado de ALU no mesmo grupo continuam exigindo detecao e stall/forwarding da Issue Unit; quatro portas de memoria nao resolvem essas dependencias.
7. **ATENCAO: stores so devem chegar como `lane_valid=1` na borda de commit autorizada**. A RAM grava fisicamente na borda positiva, entao um flush tardio ou excecao mais antiga exige bloquear stores especulativas. Este backend **nao** tem rollback/store buffer. Para exception precisa implementar commit em ordem e bloqueio de stores mais jovens.

## Viabilidade fisica (LibreLane)

O codigo de `memory_4wide.v` implementa 4R/4W **logicas** em arrays de registradores, com multiplexacao e forwarding. Ele demonstra simultaneidade funcional em RTL; **nao garante** inferencia de SRAM quad-port em ASIC. Memorias SRAM usuais nao fornecem quatro portas arbitrarias de escrita. Area, timing e consumo podem ser altos; o layout fisico deve ser analisado apos sintetizar. Um futuro backend com bancos, replicacao, log de escritas ou circuito SRAM multiportas exigira estudo de engenharia e possivel revisao de latencia, mantendo o contrato funcional.

## Testes

Executar em `rain-v/`:

```sh
sh scripts/test_gabriel.sh
```

ou, no PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test_gabriel.ps1
```

Testes incluidos: legado `memory_tb`, `memory_compat_tb`, `memory_byte_enabled_tb`; unidade `register_bank_tb`, `load_store_unit_tb`, `writeback_unit_tb`; multiportas `memory_arbiter_tb`, `memory_4wide_tb`, `memory_subsystem_4wide_tb`; `gabriel_integration_tb` com **4 stores + 4 loads + 4 writebacks num ciclo cada**. Todas as falhas devem chamar `$fatal`; ao passar imprimem `PASS`.

> Os arquivos foram preparados neste ambiente, onde Icarus Verilog nao esta disponivel. Nao afirmar PASS sem executar o script em uma maquina com `iverilog` e `vvp`.
