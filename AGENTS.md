# Eiseron AI Agent Bootloader

This project strictly adheres to the **Eiseron Engineering Constitution**. AI agents operating within this repository must retrieve their operational standards, specialized roles, and shared skills from the central Single Source of Truth (SSoT).

> [!IMPORTANT]
> This file is a **Pointer**. If the central `templates/PROJECT_AGENTS.md` is updated, this file must be synchronized accordingly.

---

## 1. Global Context (SSoT)
- **Central Repository (Remote):** `https://github.com/eiseron/eiseron-agents`
- **Mandatory Setup:** 
    1. Search for the local repository in `../eiseron-agents` (sibling) or `~/.eiseron-agents` (global).
    2. If missing, `git clone` the remote to `~/.eiseron-agents`.
- **Synchronization:** **Always** execute `git pull` within the local `eiseron-agents` directory before reading any conventions or skills to ensure the context is up-to-date.
- **Initial Task:** Once updated, perform `list_dir` and read `00-ai-conventions.md` and `AGENTS.md` to align with the global constitution and select your role.

## 2. Project-Specific Context
- **Project Specializations:** Refer to the local `./agents/` directory for any documentation, skill modules, or specialized rules unique to this project.
- **Context Extension:** Local rules in `./agents/` extend the global standards. In case of direct conflict, local definitions take precedence for this specific project.

## 3. Workflow & Verification
Follow the atomic commit, testing, and documentation procedures defined in the central repository (`skills/09-git-workflow.md` and `skills/10-documentation.md`).
