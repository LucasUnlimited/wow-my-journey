# My Journey - World of Warcraft Addon

[![WoW Version](https://img.shields.io/badge/WoW-Retail-blue)](https://worldofwarcraft.com)
[![Language](https://img.shields.io/badge/Language-Lua-language)](https://www.lua.org)
[![Framework](https://img.shields.io/badge/Framework-Pure%20API%20%28No%20Libs%29-orange)]()

**My Journey** é um addon leve e minimalista para World of Warcraft projetado para ajudar os jogadores a rastrearem seus objetivos pessoais, metas de longo prazo, materiais de profissão, montarias e conquistas diretamente dentro do jogo. 

Desenvolvido inteiramente na **API pura da Blizzard (Lua nativo)**, o addon foi desenhado para ser extremamente leve, estável e livre de dependências de frameworks de terceiros (como o Ace3).

---

## ✨ Funcionalidades

* **Rastreamento Centralizado:** Uma janela limpa e intuitiva para gerenciar suas anotações e objetivos em tempo real.
* **Magia dos Links Nativa (Shift+Clique):** Suporte total para linkar itens diretamente da sua bolsa ou coleções usando o sistema original do WoW. Para outros elementos como conquistas, missões, habilidades... é nescessário vincular ao chat do jogo e utilizar o comando (Shift+Clique).
* **Suporte a Texturas Modernas:** Ícones de interface atualizados utilizando `FileDataID` numéricos para total compatibilidade com as versões mais recentes do jogo.
* **Filtro por Personagem:** Opção visual para alternar entre exibir todos os objetivos salvos na conta ou apenas os metas do personagem atual (`Nome-Reino`).
* **Editor Integrado:** Clique em "Edit" para retornar o objetivo ao campo de entrada, permitindo correções rápidas sem perder os dados.
* **Dimensionamento Dinâmico (Text Wrapping):** Evita que textos longos ou links extensos fiquem truncados (`...`), adaptando a altura das linhas dinamicamente para manter tudo perfeitamente legível.

---

## 🛠️ Detalhes Técnicos e Soluções de API

Durante o desenvolvimento, a arquitetura do addon superou desafios específicos da API moderna da Blizzard para manter-se em Lua puro:

* **Interceptação Segura de Links:** Utiliza um hook no sistema de links global, tratando de forma inteligente a perda de foco de janelas agressivas (como o Grimório/Conquistas) para garantir a inserção no campo sem gerar erros de *Taint* na interface.
* **Gerenciamento Dinâmico de Linhas:** A interface calcula a altura de cada elemento da lista em tempo real através do método `GetStringHeight()`, ajustando o contêiner de rolagem (`ScrollFrame`) proporcionalmente.
* **Persistência Limpa:** Os dados são salvos de forma estruturada em uma tabela global única por conta, possuindo retrocompatibilidade automática para dados antigos criados em versões anteriores do addon.

---

## 🚀 Como Instalar

1. Faça o download do repositório como arquivo `.ZIP` (ou clone o repositório).
2. Extraia a pasta e certifique-se de que o diretório principal se chama exatamente `MyJourney`.
3. Mova a pasta `MyJourney` para o diretório de addons do seu jogo:
   World of Warcraft\_retail_\Interface\AddOns\
4. Inicie o World of Warcraft e certifique-se de que o addon está ativado na lista de Addons.

---

## 🎮 Como Usar
Digite /mj no chat do jogo ou clique no ícone flutuante na borda do minimapa para abrir ou fechar a janela principal.

Clique na caixa de texto para focar o cursor, segure Shift e clique em qualquer item nas suas bolsas, na sua coleção ou link compartilhado no chat para inseri-lo como link direto.

Marque a caixa "Mostrar apenas meus objetivos" no rodapé para filtrar a lista pelo seu personagem atual.

---

## 📝 Licença
Este projeto é de código aberto e está disponível para uso e modificações pessoais sob a licença MIT. Sinta-se à vontade para contribuir com melhorias na UI ou novas lógicas de organização de dados!
