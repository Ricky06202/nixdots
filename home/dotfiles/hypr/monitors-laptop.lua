-- ===== MONITORES (host: laptop) =====
-- formato: hl.monitor({ output = NOMBRE, mode = "RESOLUCION@REFRESCO", position = "XxY", scale = N })
-- HDMI-A-2 declarado primero -> es el monitor principal (ID 0)
hl.monitor({ output = "HDMI-A-2", mode = "1920x1080@60", position = "0x0", scale = 1 })
hl.monitor({ output = "eDP-1", mode = "1920x1080@60", position = "1920x0", scale = 1 })

-- ===== WORKSPACES ANCLADOS AL MONITOR PRINCIPAL =====
-- Los workspaces del escritorio viven SIEMPRE en HDMI-A-2 (persistente): si
-- eDP-1 llega a estar activa al arrancar, no se llevan los workspaces 1-5.
hl.workspace_rule({ workspace = "1", monitor = "HDMI-A-2", persistent = true })
hl.workspace_rule({ workspace = "2", monitor = "HDMI-A-2", persistent = true })
hl.workspace_rule({ workspace = "3", monitor = "HDMI-A-2", persistent = true })
hl.workspace_rule({ workspace = "4", monitor = "HDMI-A-2", persistent = true })
hl.workspace_rule({ workspace = "5", monitor = "HDMI-A-2", persistent = true })