import { frontendURL } from '../../../../helper/URLHelper';
import { ROLES } from 'dashboard/constants/permissions.js';
import KnowledgeBaseLayout from './KnowledgeBaseLayout.vue';
import KnowledgeBaseIndex from './Index.vue';
import KnowledgeBaseDetail from './Detail.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/knowledge-base'),
      component: KnowledgeBaseLayout,
      children: [
        {
          path: '',
          redirect: to => ({ name: 'knowledge_base_list', params: to.params }),
        },
        {
          path: 'list',
          name: 'knowledge_base_list',
          meta: { permissions: [...ROLES] },
          component: KnowledgeBaseIndex,
        },
        {
          path: ':id',
          name: 'knowledge_base_detail',
          meta: { permissions: [...ROLES] },
          component: KnowledgeBaseDetail,
        },
      ],
    },
  ],
};
