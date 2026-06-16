import { frontendURL } from '../../../../helper/URLHelper';
import { ROLES } from 'dashboard/constants/permissions.js';
import BranchesLayout from './BranchesLayout.vue';
import BranchesIndex from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/branches'),
      component: BranchesLayout,
      children: [
        {
          path: '',
          name: 'branches_list',
          meta: { permissions: [...ROLES] },
          component: BranchesIndex,
        },
      ],
    },
  ],
};
