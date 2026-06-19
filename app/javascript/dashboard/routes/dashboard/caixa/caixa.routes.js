import { frontendURL } from '../../../helper/URLHelper';
import { ROLES } from 'dashboard/constants/permissions.js';
import CaixaIndex from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/caixa'),
      name: 'caixa_index',
      meta: { permissions: [...ROLES] },
      component: CaixaIndex,
    },
  ],
};
