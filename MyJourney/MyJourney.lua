-- Criar as tabelas para salvar os dados entre as sessões se não existirem
MyJourneyTrack = MyJourneyTrack or {}
MyJourneySettings = MyJourneySettings or {
    minimapAngle = 45,
    showMinimap = true,
}

-- Obtém a identificação do jogador atual
local playerName, playerRealm = UnitName("player"), GetRealmName()
local currentPlayer = playerName .. "-" .. (playerRealm or "")

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

-- Comando de chat para abrir/fechar
SLASH_MYJOURNEY1 = "/mj"
SlashCmdList["MYJOURNEY"] = function()
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

-- 2. Criar o Campo de Entrada (EditBox)
local editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
editBox:SetSize(240, 30)
editBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -40)
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

-- 3. Botão de Adicionar
local btnAdicionar = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
btnAdicionar:SetSize(80, 25)
btnAdicionar:SetPoint("LEFT", editBox, "RIGHT", 10, 0)
btnAdicionar:SetText("Adicionar")

-- 4. Checkbox para Filtrar por Personagem
local chkFilter = CreateFrame("CheckButton", "MyJourneyFilterCheck", frame, "ChatConfigCheckButtonTemplate")
chkFilter:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 10)
_G[chkFilter:GetName().."Text"]:SetText(" Mostrar apenas meus objetivos")

-- 5. Container para a Lista de Objetivos
local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", editBox, "BOTTOMLEFT", 0, -20)
scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 40)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetSize(320, 1)
scrollFrame:SetScrollChild(content)

local MyJourneyTooltips = {}

-- 6. Função para Atualizar a Interface da Lista
local function AtualizarLista()
    -- Limpar linhas antigas
    for _, child in ipairs({content:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    local yOffset = 0
    local showOnlyMine = chkFilter:GetChecked()

    for index, objetivoData in ipairs(MyJourneyTrack) do
        -- Retrocompatibilidade: Se for um dado antigo salvo como string, converte para objeto
        if type(objetivoData) == "string" then
            MyJourneyTrack[index] = { text = objetivoData, author = "Desconhecido" }
            objetivoData = MyJourneyTrack[index]
        end

-- Aplica o filtro de personagem
    if not showOnlyMine or objetivoData.author == currentPlayer then
        local linha = CreateFrame("Button", nil, content)
            
        local texto = linha:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        texto:SetPoint("TOPLEFT", linha, "TOPLEFT", 5, -4) 
        texto:SetWidth(220)
        texto:SetWordWrap(true)
        texto:SetNonSpaceWrap(true)
        texto:SetJustifyH("LEFT")
        texto:SetJustifyV("TOP")
            
        -- Adiciona cor cinza para a tag do autor
        local autorTag = "|cFF888888[" .. objetivoData.author .. "]|r "
        texto:SetText(index .. ". " .. autorTag .. objetivoData.text)
            
        local textHeight = texto:GetStringHeight()
        local rowHeight = math.max(26, textHeight + 12)
        linha:SetSize(310, rowHeight)
        linha:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOffset)
            
        -- Botão para remover o objetivo
        local btnRemover = CreateFrame("Button", nil, linha)
        btnRemover:SetSize(20, 20)
        btnRemover:SetPoint("TOPRIGHT", linha, "TOPRIGHT", -5, -4)
        btnRemover:SetNormalTexture(136813) -- ID do X vermelho
        btnRemover:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        btnRemover:SetScript("OnClick", function()
            table.remove(MyJourneyTrack, index)
            AtualizarLista()
        end)

        -- Botão para editar o objetivo
        local btnEditar = CreateFrame("Button", nil, linha, "UIPanelButtonTemplate")
        btnEditar:SetSize(40, 20)
        btnEditar:SetPoint("RIGHT", btnRemover, "LEFT", -2, 0)
        btnEditar:SetText("Edit")
        btnEditar:SetScript("OnClick", function()
            editBox:SetText(objetivoData.text)
            table.remove(MyJourneyTrack, index)
            AtualizarLista()
            editBox:SetFocus()
        end)

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
    
    -- Atualiza o tamanho do container de scroll para a barra funcionar
    content:SetHeight(math.max(1, yOffset))
end

-- Lógica do Checkbox de filtro
chkFilter:SetScript("OnClick", function()
    AtualizarLista()
end)

-- Lógica do Botão Adicionar
btnAdicionar:SetScript("OnClick", function()
    local texto = editBox:GetText()
    if texto and texto ~= "" then
        -- Salva como objeto contendo o texto e quem adicionou
        table.insert(MyJourneyTrack, { text = texto, author = currentPlayer })
        editBox:SetText("")
        editBox:ClearFocus()
        AtualizarLista()
    end
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
    GameTooltip:SetText("My Journey")
    GameTooltip:AddLine("Clique para abrir/fechar.", 1, 1, 1)
    GameTooltip:AddLine("Arraste para mover.", 0.8, 0.8, 0.8)
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

-- 9. Carregar dados salvos quando o addon iniciar
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
        
        RegistrarOpcoes()
        AtualizarLista()
    end
end)