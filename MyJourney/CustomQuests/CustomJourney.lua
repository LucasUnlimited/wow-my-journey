-- Criar as tabelas para salvar os dados entre as sessões se não existirem
MyJourneyTrack = MyJourneyTrack or {}

-- Tabela para armazenar a posição e exibição do ícone no minimapa
MyJourneySettings = MyJourneySettings or {
    minimapAngle = 45,
    showMinimap = true,
}

-- Tabela para armazenar tags por personagem
MyJourneyTags = MyJourneyTags or {}

-- Obtém a identificação do jogador atual
local playerName, playerRealm = UnitName("player"), GetRealmName()
local currentPlayer = playerName .. "-" .. (playerRealm or "")

-- Função para migrar dados antigos para o novo formato separado por personagem
local function MigrateData()
    if type(MyJourneyTrack) ~= "table" then return end
    
    local isOldFormat = false
    -- Se tiver pelo menos um índice numérico, é o formato antigo
    for k, v in pairs(MyJourneyTrack) do
        if type(k) == "number" then
            isOldFormat = true
            break
        end
    end

    if isOldFormat then
        local newTrack = {}
        for _, obj in ipairs(MyJourneyTrack) do
            local text = type(obj) == "string" and obj or (obj.text or "")
            local author = type(obj) == "table" and obj.author or "Desconhecido"
            
            newTrack[author] = newTrack[author] or {}
            table.insert(newTrack[author], { text = text })
        end
        -- Substitui a tabela antiga pela nova
        wipe(MyJourneyTrack)
        for k, v in pairs(newTrack) do
            MyJourneyTrack[k] = v
        end
    end
end

-- Criar a Janela Principal usando o template básico e estável
local frame = CreateFrame("Frame", "MyJourneyFrame", UIParent, "BasicFrameTemplate")
frame:SetSize(580, 480)
frame:SetPoint("CENTER", UIParent, "CENTER")
frame.TitleText:SetText("My Journey")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:Hide() -- Começa escondido
-- Garantir que o frame do addon fique acima de outros elementos da HUD
frame:SetFrameStrata("FULLSCREEN_DIALOG")
frame:SetFrameLevel(300)
frame:SetToplevel(true)
frame:SetClampedToScreen(true)

-- Comando de chat para abrir/fechar
SLASH_MYJOURNEY1 = "/mj"
SlashCmdList["MYJOURNEY"] = function()
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

-- Campo de Entrada do objetivo (EditBox)
-- Label do campo objetivo
local lblObjetivo = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lblObjetivo:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -28)
lblObjetivo:SetText("Objetivo")
-- Campo do objetivo
local editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
editBox:SetHeight(30)
editBox:SetPoint("TOPLEFT", lblObjetivo, "BOTTOMLEFT", 0, -6)
editBox:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -44)
editBox:SetAutoFocus(false)

-- MAGIA DOS LINKS: Permitir Shift+Clique para inserir itens/conquistas (Versão Moderna)
editBox:SetScript("OnMouseDown", function(self)
    self:SetFocus()
end)

local ultimoLink, tempoLink = nil, 0

local function InserirLinkNoEditBox(link)
    if not link then return end
    
    if editBox and editBox:IsVisible() and editBox:HasFocus() then
        local agora = GetTime()
        
        -- Segurança: Previne links duplicados caso as duas APIs disparem simultaneamente no mesmo clique
        if link == ultimoLink and (agora - tempoLink) < 0.1 then
            return true
        end
        
        ultimoLink = link
        tempoLink = agora
        editBox:Insert(link)
        return true
    end
end

-- Intercepta links vindos do chat ou diário de conquistas
hooksecurefunc("ChatEdit_InsertLink", InserirLinkNoEditBox)

-- Intercepta links vindos diretamente do clique (Shift+Click) em itens da bolsa/personagem
hooksecurefunc("HandleModifiedItemClick", InserirLinkNoEditBox)

-- Campo de Entrada das tags (tagEditBox)
-- Campo da tag
local tagEditBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
tagEditBox:SetSize(380, 24)
tagEditBox:SetPoint("TOPLEFT", editBox, "BOTTOMLEFT", 0, -20)
tagEditBox:SetAutoFocus(false)
tagEditBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
-- Label do campo Tag
local lblTag = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lblTag:SetPoint("BOTTOMLEFT", tagEditBox, "TOPLEFT", 0, 6)
lblTag:SetText("Tag")

local AtualizarLista

-- Dropdown nativo para selecionar tags existentes
local tagDropdown = CreateFrame("Frame", "MyJourneyTagDropdown", frame, "UIDropDownMenuTemplate")
tagDropdown:SetSize(80, 30)
tagDropdown:SetPoint("LEFT", tagEditBox, "RIGHT", 4, -4)

local function TagDropdown_Initialize(self, level)
    level = level or 1
    if level == 1 then
        local info = UIDropDownMenu_CreateInfo()
        info.text = "(nenhuma)"
        info.arg1 = ""
        info.func = function(self)
            UIDropDownMenu_SetSelectedID(tagDropdown, self:GetID())
            tagEditBox:SetText(self.arg1)
        end
        UIDropDownMenu_AddButton(info, level)

        local tags = MyJourneyTags[currentPlayer] or {}
        for i, tag in ipairs(tags) do
            local info = UIDropDownMenu_CreateInfo()
            -- cor marrom para tags
            info.text = "|cFF8B4513" .. tag .. "|r"
            info.arg1 = tag
            info.hasArrow = true
            info.value = tag
            info.func = function(self)
                UIDropDownMenu_SetSelectedID(tagDropdown, self:GetID())
                tagEditBox:SetText(self.arg1)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    elseif level == 2 then
        local parentTag = UIDROPDOWNMENU_MENU_VALUE
        if not parentTag then return end
        local info = UIDropDownMenu_CreateInfo()
        -- adiciona ícone de remover antes do texto
        info.text = "|T136813:14|t  Remover"
        info.func = function()
            -- fechar menus antes de modificar os dados para evitar erros internos
            CloseDropDownMenus()
            -- remove tag do array de tags do jogador
            local tags = MyJourneyTags[currentPlayer] or {}
            for idx, t in ipairs(tags) do
                if t == parentTag then
                    table.remove(tags, idx)
                    break
                end
            end
            MyJourneyTags[currentPlayer] = tags
            -- opcional: limpa campo caso seja a tag removida
            if tagEditBox:GetText() == parentTag then tagEditBox:SetText("") end
            AtualizarLista()
            -- re-inicializa dropdown para refletir alterações
            UIDropDownMenu_Initialize(tagDropdown, TagDropdown_Initialize)
            UIDropDownMenu_SetText(tagDropdown, "Tag")
        end
        UIDropDownMenu_AddButton(info, level)
    end
end

UIDropDownMenu_Initialize(tagDropdown, TagDropdown_Initialize)
UIDropDownMenu_SetWidth(tagDropdown, 120)
UIDropDownMenu_SetText(tagDropdown, "Tag")

-- Botão de Adicionar
local btnAdicionar = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
btnAdicionar:SetSize(110, 26)
btnAdicionar:SetText("Adicionar")
btnAdicionar:SetPoint("TOPLEFT", tagEditBox, "BOTTOMLEFT", 0, -8)

-- Lógica do Botão Adicionar
btnAdicionar:SetScript("OnClick", function()
    local texto = editBox:GetText()
    if texto and texto ~= "" then
        local tag = tagEditBox:GetText() or ""
        MyJourneyTrack[currentPlayer] = MyJourneyTrack[currentPlayer] or {}
        table.insert(MyJourneyTrack[currentPlayer], { text = texto, tag = tag })

        -- Salva a tag para reutilização (por personagem)
        if tag and tag ~= "" then
            MyJourneyTags[currentPlayer] = MyJourneyTags[currentPlayer] or {}
            local exists = false
            for _, t in ipairs(MyJourneyTags[currentPlayer]) do
                if t == tag then exists = true break end
            end
            if not exists then table.insert(MyJourneyTags[currentPlayer], tag) end
        end

        -- Atualiza UI e limpa campos
        editBox:SetText("")
        editBox:ClearFocus()
        tagEditBox:SetText("")
        UIDropDownMenu_SetText(tagDropdown, "Tags")
        CloseDropDownMenus()
        UIDropDownMenu_Initialize(tagDropdown, TagDropdown_Initialize)
        AtualizarLista()
    end
end)

-- Checkbox para Filtrar por Personagem
local chkFilter = CreateFrame("CheckButton", "MyJourneyFilterCheck", frame, "ChatConfigCheckButtonTemplate")
chkFilter:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 10)
_G[chkFilter:GetName().."Text"]:SetText(" Mostrar apenas meus objetivos")
-- Lógica do Checkbox de filtro
chkFilter:SetScript("OnClick", function()
    AtualizarLista()
end)

-- Container para a Lista de Objetivos
local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", btnAdicionar, "BOTTOMLEFT", 0, -8)
scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, 40)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetWidth(480)
content:SetHeight(1)
scrollFrame:SetScrollChild(content)

local MyJourneyTooltips = {}

-- Extrair links com segurança, mantendo dados para Chat e Tooltip
local function GetLinks(text)
    local links = {}
    local currentPos = 1
    while true do
        local startPos, endPos, coreLink = string.find(text, "(|H.-|h.-|h)", currentPos)
        if not startPos then break end
        
        local fullLink = coreLink
        if startPos >= 11 and endPos + 2 <= #text then
            local prefix = string.sub(text, startPos - 10, startPos - 1)
            local suffix = string.sub(text, endPos + 1, endPos + 2)
            if string.match(prefix, "|c%x%x%x%x%x%x%x%x") and suffix == "|r" then
                fullLink = prefix .. coreLink .. suffix
            end
        end
        
        -- Se não tiver cor, adiciona uma cor branca padrão para não causar erro no chat
        if fullLink == coreLink then
            fullLink = "|cffffffff" .. coreLink .. "|r"
        end
        
        local innerLink = string.match(coreLink, "|H(.-)|h") or coreLink
        table.insert(links, {core = coreLink, inner = innerLink, full = fullLink})
        
        currentPos = endPos + 1
    end
    return links
end

-- Função para Atualizar a Interface da Lista
AtualizarLista = function()
    -- Limpar linhas antigas
    for _, child in ipairs({content:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    local yOffset = 0
    local showOnlyMine = chkFilter and chkFilter:GetChecked()

    -- Ordenar autores (personagem atual primeiro, depois os outros alfabeticamente)
    local authors = {}
    for author in pairs(MyJourneyTrack) do
        table.insert(authors, author)
    end
    table.sort(authors, function(a, b)
        if a == currentPlayer then return true end
        if b == currentPlayer then return false end
        return a < b
    end)

    for _, author in ipairs(authors) do
        if not showOnlyMine or author == currentPlayer then
            local lista = MyJourneyTrack[author]
            if #lista > 0 then
                -- Adicionar cabeçalho do autor
                local header = CreateFrame("Frame", nil, content)
                header:SetSize(520, 20) -- Ajusta a largura do cabeçalho do objetivo
                header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOffset)
                
                local headerText = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                headerText:SetPoint("LEFT", header, "LEFT", 4, 0)
                headerText:SetText("|cFFFFFF00[" .. author .. "]|r")
                
                yOffset = yOffset + 24

                for index, objetivoData in ipairs(lista) do
                    local linha = CreateFrame("Button", nil, content)
                        
                    local texto = linha:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                    texto:SetPoint("TOPLEFT", linha, "TOPLEFT", 4, -4) 
                    texto:SetWidth(380) -- Ajusta a largura do texto do objetivo
                    texto:SetWordWrap(true)
                    texto:SetNonSpaceWrap(true)
                    texto:SetJustifyH("LEFT")
                    texto:SetJustifyV("TOP")
                        
                    -- Exibe texto e tag (se houver)
                    if objetivoData.tag and objetivoData.tag ~= "" then
                        texto:SetText(index .. ". " .. objetivoData.text .. " |cFF8B4513[" .. objetivoData.tag .. "]|r")
                    else
                        texto:SetText(index .. ". " .. objetivoData.text)
                    end
                        
                    local textHeight = texto:GetStringHeight()
                    local rowHeight = math.max(26, textHeight + 12)
                    linha:SetSize(520, rowHeight) -- Ajusta a largura da linha do objetivo
                    linha:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOffset)
                        
                    -- Botão para remover o objetivo
                    local btnRemover = CreateFrame("Button", nil, linha)
                    btnRemover:SetSize(20, 20)
                    btnRemover:SetPoint("TOPRIGHT", linha, "TOPRIGHT", -5, -4)
                    btnRemover:SetNormalTexture(136813) -- ID do X vermelho
                    btnRemover:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
                    btnRemover:SetScript("OnClick", function()
                        table.remove(MyJourneyTrack[author], index)
                        AtualizarLista()
                    end)

                    -- Botão para editar o objetivo
                    local btnEditar = CreateFrame("Button", nil, linha, "UIPanelButtonTemplate")
                    btnEditar:SetSize(40, 20)
                    btnEditar:SetPoint("RIGHT", btnRemover, "LEFT", -2, 0)
                    btnEditar:SetText("Edit")
                    btnEditar:SetScript("OnClick", function()
                        editBox:SetText(objetivoData.text)
                        -- Preenche campo de tag ao editar para reutilização
                        if objetivoData.tag then
                            tagEditBox:SetText(objetivoData.tag)
                        else
                            tagEditBox:SetText("")
                        end
                        table.remove(MyJourneyTrack[author], index)
                        AtualizarLista()
                        editBox:SetFocus()
                    end)

                    -- Botão Descer
                    local btnDown = CreateFrame("Button", nil, linha, "UIPanelButtonTemplate")
                    btnDown:SetSize(20, 20)
                    btnDown:SetPoint("RIGHT", btnEditar, "LEFT", -2, 0)
                    btnDown:SetText("v")
                    btnDown:SetScript("OnClick", function()
                        if index < #MyJourneyTrack[author] then
                            local temp = MyJourneyTrack[author][index]
                            MyJourneyTrack[author][index] = MyJourneyTrack[author][index + 1]
                            MyJourneyTrack[author][index + 1] = temp
                            AtualizarLista()
                        end
                    end)
                    if index == #lista then btnDown:Disable() end

                    -- Botão Subir
                    local btnUp = CreateFrame("Button", nil, linha, "UIPanelButtonTemplate")
                    btnUp:SetSize(20, 20)
                    btnUp:SetPoint("RIGHT", btnDown, "LEFT", -2, 0)
                    btnUp:SetText("^")
                    btnUp:SetScript("OnClick", function()
                        if index > 1 then
                            local temp = MyJourneyTrack[author][index]
                            MyJourneyTrack[author][index] = MyJourneyTrack[author][index - 1]
                            MyJourneyTrack[author][index - 1] = temp
                            AtualizarLista()
                        end
                    end)
                    if index == 1 then btnUp:Disable() end

                    -- Ativar Tooltips para Links
                    linha:SetScript("OnEnter", function(self)
                        local i = 1
                        local prevTooltip = nil
                        
                        for _, linkData in ipairs(GetLinks(objetivoData.text)) do
                            if not MyJourneyTooltips[i] then
                                MyJourneyTooltips[i] = CreateFrame("GameTooltip", "MyJourneyTooltip"..i, UIParent, "GameTooltipTemplate")
                            end
                            local tooltip = MyJourneyTooltips[i]
                            
                            if i == 1 then
                                tooltip:SetOwner(self, "ANCHOR_RIGHT")
                            else
                                tooltip:SetOwner(self, "ANCHOR_NONE")
                                tooltip:ClearAllPoints()
                                tooltip:SetPoint("TOPLEFT", prevTooltip, "BOTTOMLEFT", 0, -2)
                            end
                            
                            tooltip:SetHyperlink(linkData.inner)
                            tooltip:Show()
                            
                            prevTooltip = tooltip
                            i = i + 1
                        end
                    end)
                    linha:SetScript("OnLeave", function() 
                        for _, tooltip in pairs(MyJourneyTooltips) do
                            tooltip:Hide()
                        end
                    end)
                        
                    linha:SetScript("OnClick", function()
                        local isModified = IsModifiedClick()
                        local first = true
                        
                        for _, linkData in ipairs(GetLinks(objetivoData.text)) do
                            if isModified then
                                -- Se tiver segurando Shift/Ctrl, processa todos (ex: manda todos pro chat)
                                HandleModifiedItemClick(linkData.full)
                            elseif first then
                                -- Clique normal (sem botão modificado), abre apenas a janela do primeiro link
                                SetItemRef(linkData.inner, linkData.full, "LeftButton")
                                first = false
                            end
                        end
                    end)

                    yOffset = yOffset + rowHeight
                end
            end
        end
    end
    
    -- Atualiza o tamanho do container de scroll para a barra funcionar
    content:SetHeight(math.max(1, yOffset))
end

-- ==========================================
-- Funcionalidade de Exportação/Importação
-- ==========================================
local btnExport = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
btnExport:SetSize(80, 22)
btnExport:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -15, 10)
btnExport:SetText("Backup")

local exportFrame = CreateFrame("Frame", "MyJourneyExportFrame", UIParent, "BasicFrameTemplate")
exportFrame:SetSize(320, 420)
exportFrame:SetPoint("CENTER", UIParent, "CENTER")
exportFrame:SetFrameStrata("FULLSCREEN_DIALOG")
exportFrame:SetToplevel(true)
exportFrame.TitleText:SetText("Exportar / Importar")
exportFrame:Hide()

local exportDesc = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
exportDesc:SetPoint("TOP", exportFrame, "TOP", 0, -30)
exportDesc:SetText("Copie o texto com Ctrl+C para exportar,\nou cole (Ctrl+V) um backup e clique Importar.")

local exportScroll = CreateFrame("ScrollFrame", nil, exportFrame, "UIPanelScrollFrameTemplate")
exportScroll:SetPoint("TOPLEFT", 15, -65)
exportScroll:SetPoint("BOTTOMRIGHT", -35, 45)

local exportEditBox = CreateFrame("EditBox", nil, exportScroll)
exportEditBox:SetMultiLine(true)
exportEditBox:SetFontObject("ChatFontNormal")
exportEditBox:SetWidth(260)
exportEditBox:SetAutoFocus(true)
exportEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() exportFrame:Hide() end)
exportScroll:SetScrollChild(exportEditBox)

-- Lógica de serialização
local function EncodeData()
    local str = "MJ_EXPORT:1\n"
    for author, lista in pairs(MyJourneyTrack) do
        for _, data in ipairs(lista) do
            local textStr = type(data) == "table" and data.text or tostring(data)
            local txt = string.gsub(textStr or "", "\n", "<MJ_NL>")
            txt = string.gsub(txt, "|", "<MJ_PIPE>")
            local tagStr = ""
            if type(data) == "table" and data.tag then
                tagStr = string.gsub(data.tag, "\n", "<MJ_NL>")
                tagStr = string.gsub(tagStr, "|", "<MJ_PIPE>")
            end
            local aut = string.gsub(author, "\n", "<MJ_NL>")
            -- Formato: texto <MJ_TAG> tag <MJ_SEP> autor
            str = str .. txt .. "<MJ_TAG>" .. tagStr .. "<MJ_SEP>" .. aut .. "\n"
        end
    end
    return str
end

local function DecodeData(str)
    local lines = {strsplit("\n", str)}
    if lines[1] ~= "MJ_EXPORT:1" then return false end
    
    local newTrack = {}
    for i = 2, #lines do
        local line = lines[i]
        if line and line ~= "" then
            local sepStart, sepEnd = string.find(line, "<MJ_SEP>")
            if sepStart then
                local left = string.sub(line, 1, sepStart - 1)
                local aut = string.sub(line, sepEnd + 1)

                -- left pode conter texto e tag separados por <MJ_TAG>
                local tagStart, tagEnd = string.find(left, "<MJ_TAG>")
                local txt = left
                local tag = ""
                if tagStart then
                    txt = string.sub(left, 1, tagStart - 1)
                    tag = string.sub(left, tagEnd + 1)
                end

                txt = string.gsub(txt, "<MJ_NL>", "\n")
                txt = string.gsub(txt, "<MJ_PIPE>", "|")
                aut = string.gsub(aut, "<MJ_NL>", "\n")
                tag = string.gsub(tag, "<MJ_NL>", "\n")
                tag = string.gsub(tag, "<MJ_PIPE>", "|")

                newTrack[aut] = newTrack[aut] or {}
                table.insert(newTrack[aut], { text = txt, tag = tag })
            end
        end
    end
    return newTrack
end

local btnImport = CreateFrame("Button", nil, exportFrame, "UIPanelButtonTemplate")
btnImport:SetSize(100, 25)
btnImport:SetPoint("BOTTOM", exportFrame, "BOTTOM", 0, 10)
btnImport:SetText("Importar")
btnImport:SetScript("OnClick", function()
    local text = exportEditBox:GetText()
    local newTrack = DecodeData(text)
    if newTrack then
        MyJourneyTrack = newTrack
        -- Reconstruir lista de tags a partir dos dados importados
        MyJourneyTags = MyJourneyTags or {}
        for author, lista in pairs(MyJourneyTrack) do
            MyJourneyTags[author] = MyJourneyTags[author] or {}
            for _, data in ipairs(lista) do
                if data.tag and data.tag ~= "" then
                    local exists = false
                    for _, t in ipairs(MyJourneyTags[author]) do if t == data.tag then exists = true break end end
                    if not exists then table.insert(MyJourneyTags[author], data.tag) end
                end
            end
        end
        AtualizarLista()
        CloseDropDownMenus()
        UIDropDownMenu_Initialize(tagDropdown, TagDropdown_Initialize)
        exportFrame:Hide()
        print("|cFF00FF00[My Journey]|r Dados importados com sucesso!")
    else
        print("|cFFFF0000[My Journey]|r Erro: Formato de dados inválido.")
    end
end)

btnExport:SetScript("OnClick", function()
    exportFrame:Show()
    exportEditBox:SetText(EncodeData())
    exportEditBox:HighlightText()
    exportEditBox:SetFocus()
end)

-- Botão do Minimapa
local minimapButton = CreateFrame("Button", "MyJourneyMinimapButton", Minimap)
minimapButton:SetSize(32, 32)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)

local minimapIcon = minimapButton:CreateTexture(nil, "BACKGROUND")
minimapIcon:SetTexture(3009385) -- Ícone do TOC
minimapIcon:SetSize(20, 20)
minimapIcon:SetPoint("TOPLEFT", 7, -6)

local minimapBorder = minimapButton:CreateTexture(nil, "OVERLAY")
minimapBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
minimapBorder:SetSize(54, 54)
minimapBorder:SetPoint("TOPLEFT")

minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
minimapButton:RegisterForDrag("LeftButton")
minimapButton:RegisterForClicks("LeftButtonUp")

local function UpdateMinimapButton()
    local angle = MyJourneySettings.minimapAngle or 45
    local radius = 100
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", radius * math.cos(math.rad(angle)), radius * math.sin(math.rad(angle)))
end

minimapButton:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        local angle = math.deg(math.atan2(cy - my, cx - mx))
        MyJourneySettings.minimapAngle = angle
        UpdateMinimapButton()
    end)
end)

minimapButton:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)

minimapButton:SetScript("OnClick", function()
    if frame:IsShown() then frame:Hide() else frame:Show() end
end)

minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("My Journey")
    GameTooltip:AddLine("Clique para abrir/fechar.", 1, 1, 1)
    GameTooltip:AddLine("Arraste para mover.", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Opções de Interface (Menu do Jogo)
local optionsPanel = CreateFrame("Frame", "MyJourneyOptionsPanel", UIParent)
optionsPanel.name = "My Journey"

local title = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("My Journey - Configurações")

local showMinimapBtn = CreateFrame("CheckButton", "MyJourneyOptionsMinimapCheck", optionsPanel, "ChatConfigCheckButtonTemplate")
showMinimapBtn:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
_G[showMinimapBtn:GetName().."Text"]:SetText(" Mostrar botão no minimapa")

showMinimapBtn:SetScript("OnClick", function(self)
    local isChecked = self:GetChecked()
    MyJourneySettings.showMinimap = isChecked
    if isChecked then
        minimapButton:Show()
    else
        minimapButton:Hide()
    end
end)

-- Função para registrar o painel de opções
local function RegistrarOpcoes()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        -- WoW Dragonflight+
        local category = Settings.RegisterCanvasLayoutCategory(optionsPanel, optionsPanel.name, optionsPanel.name)
        Settings.RegisterAddOnCategory(category)
    else
        -- WoW Classic / Expansões anteriores
        InterfaceOptions_AddCategory(optionsPanel)
    end
end

-- Carregar dados salvos quando o addon iniciar
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "MyJourney" then
        -- Garante que as configurações padrão existam
        MyJourneySettings = MyJourneySettings or {}
        if MyJourneySettings.minimapAngle == nil then MyJourneySettings.minimapAngle = 45 end
        if MyJourneySettings.showMinimap == nil then MyJourneySettings.showMinimap = true end

        -- Aplica as configurações do minimapa
        UpdateMinimapButton()
        if MyJourneySettings.showMinimap then
            minimapButton:Show()
        else
            minimapButton:Hide()
        end

        -- Aplica a configuração no checkbox do painel
        showMinimapBtn:SetChecked(MyJourneySettings.showMinimap)
        
        MigrateData()
        RegistrarOpcoes()
        AtualizarLista()
        CloseDropDownMenus()
        UIDropDownMenu_Initialize(tagDropdown, TagDropdown_Initialize)
    end
end)