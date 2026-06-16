import { frontendURL } from '../../../helper/URLHelper';
import KanbanView from './pages/KanbanView.vue';
import KanbanFunnelSettings from './pages/KanbanFunnelSettings.vue';
import { FEATURE_FLAGS } from '../../../featureFlags';

const commonMeta = {
  featureFlag: FEATURE_FLAGS.CRM,
  permissions: ['administrator', 'agent', 'contact_manage'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/kanban'),
    name: 'kanban_dashboard',
    redirect: { name: 'kanban_funnel' },
    meta: commonMeta,
  },
  {
    path: frontendURL('accounts/:accountId/kanban/funil'),
    name: 'kanban_funnel',
    component: KanbanView,
    meta: commonMeta,
  },
  {
    path: frontendURL('accounts/:accountId/kanban/funil/:funnelId/settings'),
    name: 'kanban_funnel_settings',
    component: KanbanFunnelSettings,
    meta: commonMeta,
  },
];
