-- ===== MONITORES (host: amd) =====
-- RX 7600: salida HDMI-A-1 (Samsung U28E590 4K). No hay panel interno (eDP-1
-- no existe en este host), asi que no se declara ningun segundo monitor.
-- En 1080p para que todo se vea mas grande (4K nativo se deja via escala/otros usos).
hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60", position = "0x0", scale = 1 })

-- ===== WORKSPACES ANCLADOS AL MONITOR PRINCIPAL =====
-- El host amd solo tiene un monitor: los workspaces quedan anclados a HDMI-A-1.
hl.workspace_rule({ workspace = "1", monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = "2", monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = "3", monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = "4", monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = "5", monitor = "HDMI-A-1", persistent = true })