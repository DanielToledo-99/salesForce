# Salesforce Engagement Management System

## Overview

Solución personalizada de Salesforce para gestionar Engagements con clientes, integrando Activities (Calls, Emails, Events) y Opportunities. Incluye una clase Apex controladora, un Lightning Web Component con tarjetas de resumen y una Lightning Record Page dedicada al objeto `Engagement__c`.

---

## Components Created

### 1. Custom Object: `Engagement__c`

| Field | Type | Description |
|---|---|---|
| Account | Lookup (Account) | Cuenta asociada al engagement |
| Primary Contact | Lookup (Contact) | Contacto principal |
| Related Opportunity | Lookup (Opportunity) | Oportunidad vinculada |
| Status | Picklist | Planned · In Progress · On Hold · Completed |
| Start Date | Date | Fecha de inicio |
| End Date | Date | Fecha de cierre |
| Budget | Currency | Presupuesto asignado |
| Activities | Enabled | Calls, Emails, Events habilitados |

---

### 2. Apex Class: `EngagementSummaryController`

Clase `with sharing` con 4 métodos `@AuraEnabled`, todos con try-catch y validación FLS con `WITH SECURITY_ENFORCED` / `AccessLevel.USER_MODE`.

| Method | Return | Description |
|---|---|---|
| `queryOpportunityAmount(String engagementId)` | `Decimal` | Monto de la Opportunity relacionada más reciente |
| `getCompletedTasksCount(String engagementId)` | `Integer` | Contador de Tasks con `Status = 'Completed'` |
| `getUpcomingEventsCount(String engagementId)` | `Integer` | Contador de Events con `StartDateTime >= now()` |
| `createFollowUpTask(String engagementId, String engagementName)` | `void` | Crea una Task de follow-up asignada al usuario actual |

> `queryOpportunityAmount` utiliza SOQL dinámico para detectar en runtime si el campo `Engagement__c` existe en el objeto `Opportunity`, garantizando compatibilidad con distintas configuraciones de org.

---

### 3. Lightning Web Component: `engagementSummary`

| File | Description |
|---|---|
| `engagementSummary.html` | Tres tarjetas de métricas + botón de acción + error banner |
| `engagementSummary.js` | `@wire getRecord`, carga paralela de datos con `Promise.all`, `ShowToastEvent` |
| `engagementSummary.css` | Tarjetas con gradientes SLDS (verde, azul, naranja) y hover animations |
| `engagementSummary.js-meta.xml` | Expuesto en `lightning__RecordPage` para `Engagement__c` |

**Features:**
- Lee `@api recordId` del Engagement actual vía `lightning/uiRecordApi`
- Muestra: Opportunity Amount (formato USD), Tasks completadas, Events próximos
- Botón **"Quick Follow-Up Call"** crea una Task con prioridad High para el día siguiente
- Manejo de errores con toast notifications persistentes

---

### 4. Lightning Record Page: `EngagementRecordPage`

| Property | Value |
|---|---|
| Type | RecordPage |
| Object | `Engagement__c` |
| Template | `flexipage:recordHomePinnedRightSidebarTemplateDesktop` |
| Region `main` | `c:engagementSummary` |

---

## Project Structure

```
pruebaSales/
├── sfdx-project.json
├── README.md
└── src/
    ├── classes/
    │   ├── EngagementSummaryController.cls
    │   └── EngagementSummaryController.cls-meta.xml
    ├── flexiPages/
    │   └── EngagementRecordPage.flexipage-meta.xml
    └── lwc/
        └── engagementSummary/
            ├── engagementSummary.html
            ├── engagementSummary.js
            ├── engagementSummary.css
            └── engagementSummary.js-meta.xml
```

---

## How to Deploy

### Prerequisites

- [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) installed (`sf --version`)
- Access to a Salesforce org with `Engagement__c` custom object

### Deploy Steps

```bash
# 1. Authenticate (opens browser)
sf org login web --alias dev-org

# 2. Deploy all components
sf project deploy start --source-dir src --target-org dev-org

# 3. Open org to activate the record page
sf org open --target-org dev-org --path "/visualEditor/appBuilder.app?pageId=<FlexiPageId>"
```

> **Note:** The legacy `sfdx` commands still work if you prefer:
> ```bash
> sfdx auth:web:login -a dev-org
> sfdx force:source:deploy -p src --targetusername dev-org
> ```

### Activate Record Page as Default

After deploying, activate `EngagementRecordPage` as the org default:

1. Go to **Setup → Object Manager → Engagement → Lightning Record Pages**
2. Click **EngagementRecordPage**
3. Click **Activation** → **Assign as Org Default** → **Save**

---

## Testing Instructions

1. Open any `Engagement__c` record in Salesforce
2. Verify the `engagementSummary` component renders with three metric cards:
   - **Opportunity Amount** — shows USD amount of the latest related opportunity
   - **Completed Tasks** — count of tasks linked to this engagement with `Status = Completed`
   - **Upcoming Events** — count of future events linked to this engagement
3. Click **"Quick Follow-Up Call"** to create a follow-up task
4. Confirm a success toast appears and the Tasks counter increments
5. Navigate to the related Tasks to verify the new task was created with `Priority = High`

---

## Deployed Org

| Component | ID | Status |
|---|---|---|
| Apex Class `EngagementSummaryController` | `01pbm00000PbqXVAAZ` | Active |
| LWC `engagementSummary` | `0Rbbm000004FHnpCAG` | Deployed |
| FlexiPage `EngagementRecordPage` | `0M0bm00000Cq1HFCAZ` | Deployed |
| Object `Engagement__c` | — | Active |

---

## Technical Notes

- **API Version:** 59.0
- **Security model:** `with sharing`, `WITH SECURITY_ENFORCED`, `AccessLevel.USER_MODE` — respects FLS and record sharing
- **Dynamic SOQL** used in `queryOpportunityAmount` to handle orgs where `Opportunity.Engagement__c` lookup may not exist
- **Agentforce org compatibility:** Standard `flexipage:highlights4` and `flexipage:relatedListSingle` components are not available via metadata deploy in Agentforce orgs — add them manually through the Lightning App Builder
