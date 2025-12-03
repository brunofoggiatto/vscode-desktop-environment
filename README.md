# VS Code Desktop Environment 

Este projeto configura um ambiente gráfico extremamente leve em uma máquina Ubuntu (22.04) para acesso ao VS Code via RDP, utilizando um gerenciador de janelas (Openbox).

O foco é oferecer um ambiente limpo, rápido e eficiente, pensado especificamente para programação.

Ideal para uso em:

* Servidores
* Máquinas virtuais
* Laboratórios de desenvolvimento
* Ambientes DevOps

---

## O que este script faz

* Atualiza o sistema
* Instala e configura o XRDP
* Instala um gerenciador de janelas leve (Openbox)
* Instala o VS Code
* Aplica o tema (opcional)
* Inicia automaticamente o VS Code em tela cheia
* Remove elementos visuais desnecessários (barras, menus, janelas extras)

Resultado:
Ao conectar via RDP, será exibido somente o VS Code, em modo de tela cheia, com aparência limpa e sem distrações.

---

## Requisitos

* Ubuntu 22.04
* Acesso root (ou sudo)
* Conexão com a internet

---

## Como usar

1. Clone ou copie o projeto:

```bash
git clone <url-do-repositorio>
cd vscode-desktop-environment
```

2. Dê permissão de execução ao script:

```bash
chmod +x install.sh
```

3. Execute o instalador:

```bash
sudo ./install.sh
```

4. Aguarde o término do processo de instalação.

---

## Como conectar via RDP

Use no Windows a ferramenta "Conexão de Área de Trabalho Remota":

* IP: IP da máquina Ubuntu
* Porta: 3389
* Usuário: seu usuário Linux
* Senha: sua senha Linux

Exemplo:

```text
IP: 192.xxx.0.xx
Porta: 3389
Usuário: bruno.foggiatto
Senha: ****
```

---

## Comandos úteis

Ver o IP da máquina:

```bash
hostname -I
```

Verificar status do RDP:

```bash
systemctl status xrdp
```

Reiniciar o serviço RDP:

```bash
sudo systemctl restart xrdp
```

---

## Remover Openbox (se necessário)

```bash
sudo apt remove --purge openbox obconf -y
sudo apt autoremove --purge -y
rm -rf ~/.config/openbox
```

---

## Objetivo do projeto

Criar um ambiente:

* Leve e rápido
* Totalmente focado em programação
* Ideal para desenvolvimento e práticas DevOps
* Com baixo consumo de recursos
* Livre de distrações visuais

Este ambiente foi pensado para funcionar bem mesmo em máquinas com poucos recursos, mantendo o desempenho e a simplicidade.

# AUTOR

Bruno Henrique Foggiatto
https://github.com/brunofoggiatto