-- DefaultJourney.lua

local DefaultJourney = CreateFrame("Frame")

-- Função para reordenar silenciosamente as missões do HUD por Zona/Categoria
local function ReordenarObjectiveTracker()
    local numTracked = C_QuestLog.GetNumQuestWatches()
    if numTracked <= 1 then return end -- Não precisa ordenar se houver 0 ou 1 missão

    local missoesRastreadas = {}

    -- 1. Coletar todas as missões rastreadas atualmente e suas informações de Zona
    for i = 1, numTracked do
        local questID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
        if questID then
            local questLogIndex = C_QuestLog.GetLogIndexForQuestID(questID)
            local info = C_QuestLog.GetInfo(questLogIndex)
            
            -- Pega o ID da zona/cabeçalho ou define um padrão
            local zoneHeaderID = info and info.headerQuestID or 0 
            local title = info and info.title or "Z_Desconhecido"
            
            table.insert(missoesRastreadas, {
                id = questID,
                header = zoneHeaderID,
                nome = title
            })
        end
    end

    -- 2. Ordenar a tabela primeiro pelo ID do Cabeçalho (Zona) e depois pelo nome
    table.sort(missoesRastreadas, function(a, b)
        if a.header == b.header then
            return a.nome < b.nome
        end
        return a.header < b.header
    end)

    -- 3. Remover todos os rastreios atuais
    for _, missao in ipairs(missoesRastreadas) do
        C_QuestLog.RemoveQuestWatch(missao.id)
    end

    -- 4. Adicionar de volta na ordem correta
    for _, missao in ipairs(missoesRastreadas) do
        C_QuestLog.AddQuestWatch(missao.id)
    end
    
    -- Opcional: Atualiza o Tracker visualmente
    ObjectiveTracker_Update()
end

-- Criando um comando de barra para você testar a ordenação manual
SLASH_MJORT1 = "/mjsort"
SlashCmdList["MJORT"] = function()
    ReordenarObjectiveTracker()
    print("|cFF00FF00MyJourney:|r Missões do HUD organizadas por Zona!")
end

-- Cria o botão e o atrela ao frame pai: ObjectiveTrackerFrame
local btnOrdenarHUD = CreateFrame("Button", "MyJourneySortHUDButton", ObjectiveTrackerFrame)

-- Tamanho discreto para caber no cabeçalho
btnOrdenarHUD:SetSize(20, 20) 

-- Ancora no topo direito do rastreador de missões. 
-- (Você pode ajustar o X e Y "-30, 0" para mover mais para a esquerda/direita)
btnOrdenarHUD:SetPoint("TOPRIGHT", ObjectiveTrackerFrame, "TOPRIGHT", -30, -5)

-- Texturas nativas de "Refresh/Atualizar" do próprio WoW
btnOrdenarHUD:SetNormalTexture("Interface\\Buttons\\UI-RefreshButton-Up")
btnOrdenarHUD:SetPushedTexture("Interface\\Buttons\\UI-RefreshButton-Down")
btnOrdenarHUD:SetHighlightTexture("Interface\\Buttons\\UI-RefreshButton-Highlight", "ADD")

-- O que acontece ao clicar
btnOrdenarHUD:SetScript("OnClick", function()
    -- Chama a nossa função silenciosa de ordenação
    ReordenarObjectiveTracker()
    print("|cFF00FF00MyJourney:|r Missões do HUD organizadas por Zona!")
end)

-- Adicionando um Tooltip (Caixa de dica ao passar o mouse) para ficar profissional
btnOrdenarHUD:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Ordenar Objetivos")
    GameTooltip:AddLine("Agrupa magicamente suas missões rastreadas por Zona e Categoria.", 1, 1, 1, true)
    GameTooltip:Show()
end)

btnOrdenarHUD:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)