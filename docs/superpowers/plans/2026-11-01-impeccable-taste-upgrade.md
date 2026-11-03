# Impeccable & Taste-Skill UI/UX Upgrade Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## Overview

Apply the principles of `pbakaus/impeccable` (Design Vocabulary, Anti-Slop, Deterministic UX Audit) and `Leonxlnx/taste-skill` (Domain-specific Art Direction for F&B, Reference Ergonomics, Tactile Haptics) to the `DoAnQuanLyQuanAnAI_MobileApp` project.

## File Structure & Responsibilities

1. **`DESIGN.md`** (Project Root & App Root): Single source of truth for design tokens, F&B art direction, touch target constraints, semantic colors, and agent steering commands (`/polish`, `/bolder`, `/quieter`, `/distill`, `/audit`).
2. **`.agents/skills/taste-fnb/SKILL.md`**: Agent skill instructing any AI model working on this codebase to uphold restaurant operational ergonomics and appetizing gastronomy aesthetics.
3. **`lib/screens/staff/kds_screen.dart`**: Refactored Kitchen Display System applying `/bolder` — bold glanceable table chips, timer urgency cues (>15m wait), 48dp+ tap targets for kitchen cooks, high contrast.
4. **`lib/screens/manager/ai_alerts_screen.dart`**: Refactored AI Anomaly Alerts applying `/distill` & `/clarify` — high-contrast risk badges, clear anomaly category iconography, table/invoice metadata tags, concise telemetry.
5. **`lib/screens/staff/staff_tables_screen.dart`**: Refactored Table Grid & Sheet applying `/polish` & `/audit` — 48dp+ minimum touch targets, vibrant status badges, responsive restaurant seating cards.

---

## Tasks

### Task 1: Establish `DESIGN.md` and `taste-fnb` Agent Skill

- [ ] Create `DESIGN.md` with:
  - Domain Art Direction: F&B Mobile Experience (Staff operational ergonomics, Chef KDS readability, Customer appetizing warmth).
  - Anti-Slop Rules: No generic purple-blue gradients, no nested card soup, no undersized touch targets (< 48dp).
  - Semantic Color Tokens & Typography: Currency format `đ`, contrast levels, status hierarchy.
  - Agent Steering Vocabulary: `/polish`, `/bolder`, `/quieter`, `/distill`, `/audit`.
- [ ] Create `.agents/skills/taste-fnb/SKILL.md` packaging these rules as an active skill for the AI agent harness.
- [ ] Verify both files exist and format is compliant with Markdown standards.

### Task 2: Apply `/bolder` to Kitchen Display System (`kds_screen.dart`)

- [ ] Audit touch targets in `_KdsItemRow` and `_KdsTicketCard` (ensure cook tap area is ≥ 48dp with heavy haptic feedback).
- [ ] Upgrade header typography: table name as high-contrast restaurant chip with seating indicator.
- [ ] Add urgency visual cues for tickets waiting > 15 minutes (pulsing amber/red alert tag).
- [ ] Ensure dish notes (không hành, ít cay, dị ứng...) stand out prominently with bold badge styling so the kitchen never misses allergen notes.
- [ ] Run `flutter analyze` to verify 0 syntax/typing issues.

### Task 3: Apply `/distill` & `/clarify` to AI Anomaly Alerts (`ai_alerts_screen.dart`)

- [ ] Refactor `_SummaryCard`: bold metrics, clear anomaly distribution.
- [ ] Refactor `_AlertCard`:
  - Category badges with distinct semantic icons (⚡ Speed Anomaly, 🚫 Void/Cancel Anomaly, 🏷️ Excessive Discount).
  - Prominent Table & Invoice tags (e.g. `Bàn 4`, `INV-2026...`).
  - Distill confidence meter with clear high-contrast bar.
- [ ] Enhance empty and filter states.
- [ ] Run `flutter analyze` to verify 0 issues.

### Task 4: Apply `/polish` to Staff Tables & Order Flow (`staff_tables_screen.dart`)

- [ ] Audit Table Cards: clear occupied timer, table number prominent badge, capacity icons.
- [ ] Polish Bottom Sheet:
  - Dish items list with clear kitchen status badges (`Chờ nấu`, `Đang nấu`, `Đã xong`).
  - Dual primary action buttons with standard 48dp+ height and distinct visual weight.
- [ ] Run `flutter analyze` and widget test to ensure build is pristine.

### Task 5: Final Verification & Test Suite Run

- [ ] Run `flutter analyze` across entire workspace.
- [ ] Run `flutter test test/widget_test.dart`.
- [ ] Summarize changes and design enhancements for user.
