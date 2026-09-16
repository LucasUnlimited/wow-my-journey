-- Criar as tabelas para salvar os dados entre as sessões se não existirem
MyJourneyTrack = MyJourneyTrack or {}
MyJourneySettings = MyJourneySettings or {
    minimapAngle = 45,
    showMinimap = true,
    collapsed = {},
}

-- Sistema de Localização (ptBR / enUS fallback)
local clientLocale = GetLocale()

local L = {
    -- enUS (Padrão)
    ["ADD"] = "Add",
    ["SAVE"] = "Save",
    ["CANCEL"] = "Cancel",
    ["REMOVE"] = "Remove",
    ["SHOW_ONLY_MY_GOALS"] = "Show only my goals",
    ["EDIT"] = "Edit",
    ["BACKUP"] = "Backup",
    ["EXPORT_IMPORT"] = "Export / Import",
    ["EXPORT_IMPORT_DESC"] = "Copy text with Ctrl+C to export,\nor paste (Ctrl+V) a backup and click Import.",
    ["IMPORT"] = "Import",
    ["DATA_IMPORTED"] = "|cFF00FF00[My Journey]|r Data imported successfully!",
    ["DATA_ERROR"] = "|cFFFF0000[My Journey]|r Error: Invalid data format.",
    ["MINIMAP_TOOLTIP_TITLE"] = "My Journey",
    ["MINIMAP_TOOLTIP_CLICK"] = "Click to open/close.",
    ["MINIMAP_TOOLTIP_DRAG"] = "Drag to move.",
    ["SETTINGS_TITLE"] = "My Journey - Settings",
    ["SHOW_MINIMAP_BUTTON"] = "Show minimap button",
    ["UNKNOWN"] = "Unknown",
    ["COLLAPSE"] = "Click to collapse",
    ["EXPAND"] = "Click to expand",
    ["PLACEHOLDER_GOAL"] = "Write your Goal and add to the list",
}

if clientLocale == "ptBR" then
    L["ADD"] = "Adicionar"
    L["SAVE"] = "Salvar"
    L["CANCEL"] = "Cancelar"
    L["REMOVE"] = "Remover"
    L["SHOW_ONLY_MY_GOALS"] = "Mostrar apenas meus objetivos"
    L["EDIT"] = "Editar"
    L["BACKUP"] = "Backup"
    L["EXPORT_IMPORT"] = "Exportar / Importar"
    L["EXPORT_IMPORT_DESC"] = "Copie o texto com Ctrl+C para exportar,\nou cole (Ctrl+V) um backup e clique Importar."
    L["IMPORT"] = "Importar"
    L["DATA_IMPORTED"] = "|cFF00FF00[My Journey]|r Dados importados com sucesso!"
    L["DATA_ERROR"] = "|cFFFF0000[My Journey]|r Erro: Formato de dados inválido."
    L["MINIMAP_TOOLTIP_TITLE"] = "My Journey"
    L["MINIMAP_TOOLTIP_CLICK"] = "Clique para abrir/fechar."
    L["MINIMAP_TOOLTIP_DRAG"] = "Arraste para mover."
    L["SETTINGS_TITLE"] = "My Journey - Configurações"
    L["SHOW_MINIMAP_BUTTON"] = "Mostrar botão no minimapa"
    L["UNKNOWN"] = "Desconhecido"
    L["COLLAPSE"] = "Clique para recolher"
    L["EXPAND"] = "Clique para expandir"
    L["PLACEHOLDER_GOAL"] = "Escreva seu objetivo e adicione à lista"
end

setmetatable(L, {
    __index = function(t, k)
        return k
    end
})

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
            local author = type(obj) == "table" and obj.author or L["UNKNOWN"]
            
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

-- 1. Criar a Janela Principal usando o template básico e estável
local frame = CreateFrame("Frame", "MyJourneyFrame", UIParent, "BasicFrameTemplate")
frame:SetSize(380, 480)
frame:SetPoint("CENTER", UIParent, "CENTER")
frame.TitleText:SetText("My Journey")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:Hide() -- Começa escondido
-- Garantir que o frame do addon fique acima de outros elementos da HUD
frame:SetFrameStrata("FULLSCREEN")
frame:SetFrameLevel(300)
frame:SetToplevel(true)
frame:SetClampedToScreen(true)

-- Comando de chat para abrir/fechar
SLASH_MYJOURNEY1 = "/mj"
SlashCmdList["MYJOURNEY"] = function()
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

-- Variáveis de controle de edição e funções
local AtualizarLista
local CancelarEdicao
local IniciarEdicao
local SalvarOuAdicionar
local UpdateInputLayout
local UpdateInputHeight
local editingGoal = nil

-- 2. Criar o Campo de Entrada (Container, Ícone !, EditBox e Placeholder)
local inputContainer = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
inputContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -38)
inputContainer:SetSize(335, 28)
inputContainer:SetClipsChildren(true)

inputContainer:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
inputContainer:SetBackdropColor(0.06, 0.06, 0.06, 0.75)
inputContainer:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.7)

-- Ícone de Missão (!) na esquerda
local questBtn = CreateFrame("Button", nil, inputContainer)
questBtn:SetSize(16, 16)
questBtn:SetPoint("TOPLEFT", inputContainer, "TOPLEFT", 6, -6)

local questIcon = questBtn:CreateTexture(nil, "ARTWORK")
questIcon:SetAllPoints()
questIcon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")

-- EditBox multiline
local editBox = CreateFrame("EditBox", nil, inputContainer)
editBox:SetMultiLine(true)
editBox:SetFontObject("ChatFontNormal")
editBox:SetTextColor(1, 1, 1, 1)
editBox:SetAutoFocus(false)
editBox:SetPoint("TOPLEFT", inputContainer, "TOPLEFT", 26, -6)
editBox:SetPoint("BOTTOMRIGHT", inputContainer, "BOTTOMRIGHT", -6, 6)

-- Placeholder quando vazio
local placeholder = inputContainer:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
placeholder:SetPoint("TOPLEFT", editBox, "TOPLEFT", 0, 0)
placeholder:SetPoint("BOTTOMRIGHT", editBox, "BOTTOMRIGHT", 0, 0)
placeholder:SetJustifyH("LEFT")
placeholder:SetJustifyV("TOP")
placeholder:SetTextColor(0.55, 0.55, 0.55, 0.85)
placeholder:SetWordWrap(false)
placeholder:SetText(L["PLACEHOLDER_GOAL"])

-- FontString auxiliar para medir a altura do texto com wrap
local measureText = frame:CreateFontString(nil, "BACKGROUND", "ChatFontNormal")
measureText:Hide()
measureText:SetWordWrap(true)
measureText:SetNonSpaceWrap(true)

-- Clicar em qualquer parte do container ou no ícone de missão foca o editbox
questBtn:SetScript("OnClick", function()
    editBox:SetFocus()
end)

inputContainer:EnableMouse(true)
inputContainer:SetScript("OnMouseDown", function()
    editBox:SetFocus()
end)

-- 3. Botão de Adicionar e Botão de Cancelar
local btnAdicionar = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
btnAdicionar:SetSize(72, 26)
btnAdicionar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -25, -38)
btnAdicionar:SetText(L["ADD"])
btnAdicionar:Hide()

local btnCancelar = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
btnCancelar:SetSize(22, 26)
btnCancelar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -25, -38)
btnCancelar:SetText("X")
btnCancelar:Hide()

btnCancelar:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["CANCEL"])
    GameTooltip:Show()
end)

btnCancelar:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

btnCancelar:SetScript("OnClick", function()
    CancelarEdicao()
end)

UpdateInputHeight = function()
    local text = editBox:GetText() or ""
    local editWidth = editBox:GetWidth()
    if not editWidth or editWidth <= 0 then
        local isCompact = btnAdicionar:IsShown()
        editWidth = (isCompact and 250 or 335) - 32
    end

    measureText:SetWidth(editWidth)

    -- Conta quebras de linha explícitas para garantir a altura mínima correspondente
    local _, newlineCount = string.gsub(text, "\n", "")

    -- Adiciona espaço após cada newline para que linhas vazias ou no final sejam medidas pelo FontString
    local measureString = string.gsub(text, "\n", "\n ")
    if measureString == "" then
        measureString = " "
    end
    measureText:SetText(measureString)

    local stringHeight = measureText:GetStringHeight()
    local minLinesHeight = (newlineCount + 1) * 15
    local textHeight = math.max(stringHeight, minLinesHeight)
    local targetHeight = math.max(28, math.min(120, math.ceil(textHeight + 14)))
    inputContainer:SetHeight(targetHeight)
    editBox:SetHeight(targetHeight - 12)
end

UpdateInputLayout = function()
    local hasFocus = editBox:HasFocus()
    local text = editBox:GetText() or ""
    local hasText = (text ~= "")
    local isEditing = (editingGoal ~= nil)

    local isCompact = hasFocus or hasText or isEditing

    if isCompact then
        if isEditing then
            btnCancelar:SetSize(22, 26)
            btnCancelar:ClearAllPoints()
            btnCancelar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -25, -38)
            btnCancelar:Show()

            btnAdicionar:SetSize(54, 26)
            btnAdicionar:ClearAllPoints()
            btnAdicionar:SetPoint("RIGHT", btnCancelar, "LEFT", -4, 0)
            btnAdicionar:SetText(L["SAVE"])
            btnAdicionar:Show()

            inputContainer:SetWidth(248)
        else
            btnCancelar:Hide()

            btnAdicionar:SetSize(72, 26)
            btnAdicionar:ClearAllPoints()
            btnAdicionar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -25, -38)
            btnAdicionar:SetText(L["ADD"])
            btnAdicionar:Show()

            inputContainer:SetWidth(252)
        end
    else
        btnAdicionar:Hide()
        btnCancelar:Hide()
        inputContainer:SetWidth(335)
    end

    if text == "" then
        placeholder:Show()
    else
        placeholder:Hide()
    end

    if hasFocus then
        inputContainer:SetBackdropBorderColor(0.75, 0.75, 0.75, 0.95)
    else
        inputContainer:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.7)
    end

    UpdateInputHeight()
end

editBox:SetScript("OnEditFocusGained", function(self)
    UpdateInputLayout()
end)

editBox:SetScript("OnEditFocusLost", function(self)
    C_Timer.After(0.05, function()
        UpdateInputLayout()
    end)
end)

editBox:SetScript("OnTextChanged", function(self, userInput)
    if not self:HasFocus() and self:GetText() == "\n" then
        self:SetText("")
        return
    end
    UpdateInputLayout()
end)

editBox:SetScript("OnEscapePressed", function(self)
    if editingGoal then
        CancelarEdicao()
    else
        self:ClearFocus()
        UpdateInputLayout()
    end
end)

editBox:SetScript("OnKeyDown", function(self, key)
    if key == "ENTER" then
        if IsShiftKeyDown() then
            self:Insert("\n")
        else
            if SalvarOuAdicionar then
                SalvarOuAdicionar()
            end
        end
    end
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

CancelarEdicao = function()
    editingGoal = nil
    editBox:SetText("")
    editBox:ClearFocus()
    UpdateInputLayout()
    if AtualizarLista then
        AtualizarLista()
    end
end

IniciarEdicao = function(author, objetivoData)
    editingGoal = { author = author, item = objetivoData }
    editBox:SetText(objetivoData.text)
    editBox:SetFocus()
    UpdateInputLayout()
    if AtualizarLista then
        AtualizarLista()
    end
end

-- Inicializa o layout do input no estado padrão (largura total, sem botões)
UpdateInputLayout()

-- 4. Checkbox para Filtrar por Personagem
local chkFilter = CreateFrame("CheckButton", "MyJourneyFilterCheck", frame, "ChatConfigCheckButtonTemplate")
chkFilter:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 10)
_G[chkFilter:GetName().."Text"]:SetText(L["SHOW_ONLY_MY_GOALS"])
chkFilter:SetChecked(true)

-- 5. Container para a Lista de Objetivos
local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", inputContainer, "BOTTOMLEFT", 0, -15)
scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 40)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetSize(320, 1)
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

-- 6. Função para Atualizar a Interface da Lista
AtualizarLista = function()
    -- Limpar linhas antigas
    for _, child in ipairs({content:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    local yOffset = 0
    local showOnlyMine = chkFilter:GetChecked()

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
                local isCollapsed = MyJourneySettings.collapsed and MyJourneySettings.collapsed[author]

                -- Adicionar cabeçalho do autor (clicável para recolher/expandir)
                local header = CreateFrame("Button", nil, content)
                header:SetSize(310, 20)
                header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOffset)
                header:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight", "ADD")
                
                local icon = header:CreateTexture(nil, "ARTWORK")
                icon:SetSize(14, 14)
                icon:SetPoint("LEFT", header, "LEFT", 2, 0)
                if isCollapsed then
                    icon:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
                else
                    icon:SetTexture("Interface\\Buttons\\UI-MinusButton-Up")
                end

                local headerText = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                headerText:SetPoint("LEFT", icon, "RIGHT", 4, 0)
                headerText:SetText("|cFFFFFF00[" .. author .. "]|r |cFF888888(" .. #lista .. ")|r")

                header:SetScript("OnClick", function()
                    MyJourneySettings.collapsed = MyJourneySettings.collapsed or {}
                    MyJourneySettings.collapsed[author] = not MyJourneySettings.collapsed[author]
                    GameTooltip:Hide()
                    AtualizarLista()
                end)

                header:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    local collapsedNow = MyJourneySettings.collapsed and MyJourneySettings.collapsed[author]
                    GameTooltip:SetText(collapsedNow and L["EXPAND"] or L["COLLAPSE"])
                    GameTooltip:Show()
                end)

                header:SetScript("OnLeave", function()
                    GameTooltip:Hide()
                end)
                
                yOffset = yOffset + 24

                if not isCollapsed then
                    for index, objetivoData in ipairs(lista) do
                    local linha = CreateFrame("Button", nil, content)
                    local isEditingThis = editingGoal and editingGoal.item == objetivoData
                        
                    local texto = linha:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                    texto:SetPoint("TOPLEFT", linha, "TOPLEFT", 15, -4) 
                    texto:SetWidth(175) -- reduzido para caber os botões
                    texto:SetWordWrap(true)
                    texto:SetNonSpaceWrap(true)
                    texto:SetJustifyH("LEFT")
                    texto:SetJustifyV("TOP")
                        
                    texto:SetText(index .. ". " .. objetivoData.text)
                    if isEditingThis then
                        texto:SetTextColor(1, 0.82, 0)
                    end
                        
                    local textHeight = texto:GetStringHeight()
                    local rowHeight = math.max(26, textHeight + 12)
                    linha:SetSize(310, rowHeight)
                    linha:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOffset)
                        
                    -- Botão para remover o objetivo
                    local btnRemover = CreateFrame("Button", nil, linha, "UIPanelButtonTemplate")
                    btnRemover:SetSize(20, 20)
                    btnRemover:SetPoint("TOPRIGHT", linha, "TOPRIGHT", -5, -4)
                    btnRemover:SetText("X")
                    btnRemover:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetText(L["REMOVE"])
                        GameTooltip:Show()
                    end)
                    btnRemover:SetScript("OnLeave", function()
                        GameTooltip:Hide()
                    end)
                    btnRemover:SetScript("OnClick", function()
                        GameTooltip:Hide()
                        if editingGoal and editingGoal.item == objetivoData then
                            CancelarEdicao()
                        end
                        table.remove(MyJourneyTrack[author], index)
                        AtualizarLista()
                    end)

                    -- Botão para editar o objetivo
                    local btnEditar = CreateFrame("Button", nil, linha, "UIPanelButtonTemplate")
                    btnEditar:SetSize(45, 20)
                    btnEditar:SetPoint("RIGHT", btnRemover, "LEFT", -2, 0)
                    btnEditar:SetText(L["EDIT"])
                    if isEditingThis then
                        btnEditar:Disable()
                    else
                        btnEditar:Enable()
                    end
                    btnEditar:SetScript("OnClick", function()
                        IniciarEdicao(author, objetivoData)
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
    end
    
    -- Atualiza o tamanho do container de scroll para a barra funcionar
    content:SetHeight(math.max(1, yOffset))
end

-- Lógica do Checkbox de filtro
chkFilter:SetScript("OnClick", function()
    AtualizarLista()
end)

-- Lógica do Botão Adicionar / Salvar
SalvarOuAdicionar = function()
    local texto = editBox:GetText()
    if texto then
        texto = string.gsub(texto, "^%s*(.-)%s*$", "%1")
    end
    if texto and texto ~= "" then
        if editingGoal and editingGoal.item then
            local authorList = MyJourneyTrack[editingGoal.author]
            local found = false
            if authorList then
                for _, obj in ipairs(authorList) do
                    if obj == editingGoal.item then
                        obj.text = texto
                        found = true
                        break
                    end
                end
            end
            if not found then
                local targetAuthor = editingGoal.author or currentPlayer
                MyJourneyTrack[targetAuthor] = MyJourneyTrack[targetAuthor] or {}
                table.insert(MyJourneyTrack[targetAuthor], { text = texto })
            end
            CancelarEdicao()
        else
            MyJourneyTrack[currentPlayer] = MyJourneyTrack[currentPlayer] or {}
            table.insert(MyJourneyTrack[currentPlayer], { text = texto })
            editBox:SetText("")
            editBox:ClearFocus()
            if MyJourneySettings.collapsed then
                MyJourneySettings.collapsed[currentPlayer] = false
            end
            UpdateInputLayout()
            AtualizarLista()
        end
    end
end

btnAdicionar:SetScript("OnClick", SalvarOuAdicionar)

-- ==========================================
-- 6b. Funcionalidade de Exportação/Importação
-- ==========================================
local btnExport = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
btnExport:SetSize(80, 22)
btnExport:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -15, 10)
btnExport:SetText(L["BACKUP"])

local exportFrame = CreateFrame("Frame", "MyJourneyExportFrame", frame, "BasicFrameTemplate")
exportFrame:SetSize(320, 420)
exportFrame:SetPoint("CENTER", UIParent, "CENTER")
exportFrame:SetFrameStrata("FULLSCREEN_DIALOG")
exportFrame.TitleText:SetText(L["EXPORT_IMPORT"])
exportFrame:Hide()

local exportDesc = exportFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
exportDesc:SetPoint("TOP", exportFrame, "TOP", 0, -30)
exportDesc:SetText(L["EXPORT_IMPORT_DESC"])

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
            local aut = string.gsub(author, "\n", "<MJ_NL>")
            str = str .. txt .. "<MJ_SEP>" .. aut .. "\n"
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
                local txt = string.sub(line, 1, sepStart - 1)
                local aut = string.sub(line, sepEnd + 1)
                txt = string.gsub(txt, "<MJ_NL>", "\n")
                txt = string.gsub(txt, "<MJ_PIPE>", "|")
                aut = string.gsub(aut, "<MJ_NL>", "\n")
                
                newTrack[aut] = newTrack[aut] or {}
                table.insert(newTrack[aut], { text = txt })
            end
        end
    end
    return newTrack
end

local btnImport = CreateFrame("Button", nil, exportFrame, "UIPanelButtonTemplate")
btnImport:SetSize(100, 25)
btnImport:SetPoint("BOTTOM", exportFrame, "BOTTOM", 0, 10)
btnImport:SetText(L["IMPORT"])
btnImport:SetScript("OnClick", function()
    local text = exportEditBox:GetText()
    local newTrack = DecodeData(text)
    if newTrack then
        if editingGoal then
            CancelarEdicao()
        end
        MyJourneyTrack = newTrack
        AtualizarLista()
        exportFrame:Hide()
        print(L["DATA_IMPORTED"])
    else
        print(L["DATA_ERROR"])
    end
end)

btnExport:SetScript("OnClick", function()
    exportFrame:Show()
    exportEditBox:SetText(EncodeData())
    exportEditBox:HighlightText()
    exportEditBox:SetFocus()
end)

-- 7. Botão do Minimapa
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
    GameTooltip:SetText(L["MINIMAP_TOOLTIP_TITLE"])
    GameTooltip:AddLine(L["MINIMAP_TOOLTIP_CLICK"], 1, 1, 1)
    GameTooltip:AddLine(L["MINIMAP_TOOLTIP_DRAG"], 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- 8. Opções de Interface (Menu do Jogo)
local optionsPanel = CreateFrame("Frame", "MyJourneyOptionsPanel", UIParent)
optionsPanel.name = "My Journey"

local title = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText(L["SETTINGS_TITLE"])

local showMinimapBtn = CreateFrame("CheckButton", "MyJourneyOptionsMinimapCheck", optionsPanel, "ChatConfigCheckButtonTemplate")
showMinimapBtn:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
_G[showMinimapBtn:GetName().."Text"]:SetText(L["SHOW_MINIMAP_BUTTON"])

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

-- 9. Carregar dados salvos quando o addon iniciar
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "MyJourney" then
        -- Garante que as configurações padrão existam
        MyJourneySettings = MyJourneySettings or {}
        if MyJourneySettings.minimapAngle == nil then MyJourneySettings.minimapAngle = 45 end
        if MyJourneySettings.showMinimap == nil then MyJourneySettings.showMinimap = true end
        if MyJourneySettings.collapsed == nil then MyJourneySettings.collapsed = {} end

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
        UpdateInputLayout()
        AtualizarLista()
    end
end)