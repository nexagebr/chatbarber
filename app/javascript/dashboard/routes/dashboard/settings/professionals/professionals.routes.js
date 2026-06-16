import { frontendURL } from '../../../../helper/URLHelper';
import { ROLES } from 'dashboard/constants/permissions.js';
import ProfessionalsLayout from './ProfessionalsLayout.vue';
import ProfessionalsIndex from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/professionals'),
      component: ProfessionalsLayout,
      children: [
        {
          path: '',
          name: 'professionals_list',
          meta: { permissions: [...ROLES] },
          component: ProfessionalsIndex,
        },
      ],
    },
  ],
};
