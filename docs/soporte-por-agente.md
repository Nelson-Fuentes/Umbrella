# Soporte por agente

Generado por `scripts/support_matrix.py` a partir de la tabla de capacidades
que el rulesync instalado (version fijada en `package.json`) reporta con
`rulesync docs reference/supported-tools`. No es una lista de memoria: si una
version nueva de rulesync agrega o quita un target, esta tabla cambia solo
con volver a correr `./build.sh`.

`restriccion de herramientas` y `modelo` dependen del contenido final de cada
subagente generado, archivo por archivo, por target; esta pasada automatica
no los verifica uno por uno y los marca `[VERIFICAR]`.

| Agente (--targets) | Skills | Subagentes | Reglas | Hooks | Restriccion de herramientas | Modelo |
| --- | --- | --- | --- | --- | --- | --- |
| AGENTS.md (`agentsmd`) | degradado (simulado) | degradado (simulado) | si | no | [VERIFICAR] | [VERIFICAR] |
| AgentsSkills (`agentsskills`) | si | no | no | no | [VERIFICAR] | [VERIFICAR] |
| Amp (`amp`) | si | no | si | si | [VERIFICAR] | [VERIFICAR] |
| IBM Bob (`bob`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| Claude Code (`claudecode`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| Claude Code plugin (`claudecode-plugin`) | si | si | no | si | [VERIFICAR] | [VERIFICAR] |
| CodeBuddy Code (`codebuddy`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| Codewhale (`codewhale`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| Codex CLI (`codexcli`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| Command Code (`commandcode`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| GitHub Copilot (`copilot`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| GitHub Copilot CLI (`copilotcli`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| Crush (`crush`) | si | no | si | si | [VERIFICAR] | [VERIFICAR] |
| Goose (`goose`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| Hermes Agent (`hermesagent`) | no | si | si | no | [VERIFICAR] | [VERIFICAR] |
| Grok CLI (`grokcli`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| Cursor (`cursor`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| deepagents-cli (`deepagents`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| Factory Droid (`factorydroid`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| Firebender (`firebender`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| OpenCode (`opencode`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| OpenCode V1 (`opencodev1`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| OpenClaw (`openclaw`) | no | no | si | no | [VERIFICAR] | [VERIFICAR] |
| MiMo Code (`mimocode`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| GitLab Duo CLI (`gitlabduo`) | si | no | si | si | [VERIFICAR] | [VERIFICAR] |
| Cline (`cline`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| Kilo Code (`kilo`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| Kimi Code (`kimi-code`) | si | si | si | no | [VERIFICAR] | [VERIFICAR] |
| Kimi Code plugin (`kimi-code-plugin`) | si | si | si | no | [VERIFICAR] | [VERIFICAR] |
| Roo Code (`roo`) | si | si | si | no | [VERIFICAR] | [VERIFICAR] |
| Zoo Code (`zoocode`) | si | si | si | no | [VERIFICAR] | [VERIFICAR] |
| Rovodev (Atlassian) (`rovodev`) | si | si | si | no | [VERIFICAR] | [VERIFICAR] |
| Takt (`takt`) | si | si | si | no | [VERIFICAR] | [VERIFICAR] |
| Trae (`trae`) | si | no | si | si | [VERIFICAR] | [VERIFICAR] |
| Tabnine CLI (`tabnine`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| Continue (`continue`) | si | no | si | si | [VERIFICAR] | [VERIFICAR] |
| Snowflake Cortex Code (`cortexcode`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| Vibe Code (`vibe`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| Vibe Code plugin (`vibe-plugin`) | si | si | no | si | [VERIFICAR] | [VERIFICAR] |
| Qoder (`qoder`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| Qwen Code (`qwencode`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| Meta Muse Code (`musecode`) | si | no | si | no | [VERIFICAR] | [VERIFICAR] |
| Reasonix (`reasonix`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| Codebuff (Freebuff) (`codebuff`) | no | no | no | no | [VERIFICAR] | [VERIFICAR] |
| Kiro (`kiro`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| Kiro CLI (`kiro-cli`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| Kiro IDE (`kiro-ide`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| Letta Code (`lettacode`) | si | si | no | si | [VERIFICAR] | [VERIFICAR] |
| Google Antigravity IDE (`antigravity-ide`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| Google Antigravity CLI (`antigravity-cli`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| Google Antigravity plugin (`antigravity-plugin`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| JetBrains AI Assistant (`aiassistant`) | si | no | si | no | [VERIFICAR] | [VERIFICAR] |
| Gemini in Android Studio (`androidstudio`) | si | no | no | no | [VERIFICAR] | [VERIFICAR] |
| JetBrains Junie (`junie`) | si | si | si | no | [VERIFICAR] | [VERIFICAR] |
| AugmentCode (`augmentcode`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| AugmentCode plugin (`augmentcode-plugin`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| Devin Desktop (`devin`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| Devin plugin (`devin-plugin`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| Warp (`warp`) | si | no | si | no | [VERIFICAR] | [VERIFICAR] |
| Warp Agent CLI (`warpcli`) | no | no | no | no | [VERIFICAR] | [VERIFICAR] |
| Xum (`xum`) | si | si | si | no | [VERIFICAR] | [VERIFICAR] |
| Replit (`replit`) | si | no | si | no | [VERIFICAR] | [VERIFICAR] |
| Pi Coding Agent (`pi`) | si | no | si | si | [VERIFICAR] | [VERIFICAR] |
| oh-my-pi (`omp`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| Zed (`zed`) | si | no | si | no | [VERIFICAR] | [VERIFICAR] |
| ZCode (Z.ai) (`zcode`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| ZCode plugin (`zcode-plugin`) | si | si | no | si | [VERIFICAR] | [VERIFICAR] |
| Pool (Poolside) (`pool`) | si | si | si | si | [VERIFICAR] | [VERIFICAR] |
| DeepSeek Harness (`dsh`) | si | no | si | no | [VERIFICAR] | [VERIFICAR] |
