import { frontendURL } from '../../../helper/URLHelper';
import { ROLES } from 'dashboard/constants/permissions.js';
import AppointmentsIndex from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/agenda'),
      name: 'agenda_index',
      meta: { permissions: [...ROLES] },
      component: AppointmentsIndex,
    },
  ],
};
