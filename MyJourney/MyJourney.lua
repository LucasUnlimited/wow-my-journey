-- Criar a tabela para salvar os dados entre as sessões se não existir
MyJourneyTrack = MyJourneyTrack or {}

-- Obtém a identificação do jogador atual
local playerName, playerRealm = UnitName("player"), GetRealmName()
local currentPlayer = playerName .. "-" .. (playerRealm or "")

-- 1. Criar a Janela Principal usando o template básico e estável
local frame = CreateFrame("Frame", "MyJourneyFrame", UIParent, "BasicFrameTemplate")
frame:SetSize(380, 480) -- Aumentei levemente para acomodar botoes extras
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

        -- Ativar Tooltips para Links
        linha:SetScript("OnEnter", function()
            local link = string.match(objetivoData.text, "(|H.-|h.-|h)")
            if link then
                    GameTooltip:SetOwner(linha, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink(link)
                    GameTooltip:Show()
            end
        end)
        linha:SetScript("OnLeave", function() GameTooltip:Hide() end)
            
        linha:SetScript("OnClick", function()
            local link = string.match(objetivoData.text, "(|H.-|h.-|h)")
            if link then
                    SetItemRef(link, link, "LeftButton")
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

-- Carregar dados salvos quando o addon iniciar
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "MyJourney" then
        AtualizarLista()
    end
end)