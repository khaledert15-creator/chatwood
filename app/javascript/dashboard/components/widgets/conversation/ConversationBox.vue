<script>
import { mapGetters } from 'vuex';
import { useMediaQuery } from '@vueuse/core';
import { LocalStorage } from 'shared/helpers/localStorage';
import ConversationHeader from './ConversationHeader.vue';
import DashboardAppFrame from '../DashboardApp/Frame.vue';
import EmptyState from './EmptyState/EmptyState.vue';
import MessagesView from './MessagesView.vue';

const SIDE_APP_STORAGE_KEY = 'chatwoot.dashboardApp.side';

export default {
  components: {
    ConversationHeader,
    DashboardAppFrame,
    EmptyState,
    MessagesView,
  },
  props: {
    inboxId: {
      type: [Number, String],
      default: '',
      required: false,
    },
    isInboxView: {
      type: Boolean,
      default: false,
    },
    isContactPanelOpen: {
      type: Boolean,
      default: true,
    },
    isOnExpandedLayout: {
      type: Boolean,
      default: true,
    },
  },
  setup() {
    // A dashboard app pinned beside the messages needs room for both; narrower screens keep the tabs.
    return { isWideScreen: useMediaQuery('(min-width: 1024px)') };
  },
  data() {
    return {
      activeIndex: 0,
      sideAppId: LocalStorage.get(SIDE_APP_STORAGE_KEY),
    };
  },
  computed: {
    ...mapGetters({
      currentChat: 'getSelectedChat',
      dashboardApps: 'dashboardApps/getRecords',
    }),
    sideApp() {
      if (!this.isWideScreen) return null;
      return this.dashboardApps.find(app => app.id === this.sideAppId) || null;
    },
    tabApps() {
      return this.dashboardApps.filter(app => app !== this.sideApp);
    },
    dashboardAppTabs() {
      return [
        {
          key: 'messages',
          index: 0,
          name: this.$t('CONVERSATION.DASHBOARD_APP_TAB_MESSAGES'),
        },
        ...this.tabApps.map((dashboardApp, index) => ({
          key: `dashboard-${dashboardApp.id}`,
          index: index + 1,
          name: dashboardApp.title,
        })),
      ];
    },
    activeTabApp() {
      return this.tabApps[this.activeIndex - 1] || null;
    },
    showContactPanel() {
      return this.isContactPanelOpen && this.currentChat.id;
    },
  },
  watch: {
    'currentChat.inbox_id': {
      immediate: true,
      handler(inboxId) {
        if (inboxId) {
          this.$store.dispatch('inboxAssignableAgents/fetch', {
            inboxIds: [inboxId],
            includeAgentBots: true,
          });
        }
      },
    },
    'currentChat.id'() {
      this.fetchLabels();
      this.activeIndex = 0;
    },
  },
  mounted() {
    this.fetchLabels();
    this.$store.dispatch('dashboardApps/get');
  },
  methods: {
    fetchLabels() {
      if (!this.currentChat.id) {
        return;
      }
      this.$store.dispatch('conversationLabels/get', this.currentChat.id);
    },
    onDashboardAppTabChange(index) {
      this.activeIndex = index;
    },
    setSideApp(app) {
      this.sideAppId = app ? app.id : null;
      LocalStorage.set(SIDE_APP_STORAGE_KEY, this.sideAppId);
      this.activeIndex = 0;
    },
  },
};
</script>

<template>
  <div
    class="conversation-details-wrap flex flex-col min-w-0 w-full bg-n-surface-1 relative"
    :class="{
      'border-l rtl:border-l-0 rtl:border-r border-n-weak': !isOnExpandedLayout,
    }"
  >
    <ConversationHeader
      v-if="currentChat.id"
      :chat="currentChat"
      :show-back-button="isOnExpandedLayout && !isInboxView"
      :class="{
        'border-b border-b-n-weak !pt-2': !tabApps.length,
      }"
    />
    <div
      v-if="tabApps.length && currentChat.id"
      class="flex items-center h-10 gap-2"
    >
      <woot-tabs
        :index="activeIndex"
        class="h-10 flex-1 min-w-0"
        @change="onDashboardAppTabChange"
      >
        <woot-tabs-item
          v-for="tab in dashboardAppTabs"
          :key="tab.key"
          :index="tab.index"
          :name="tab.name"
          :show-badge="false"
          is-compact
        />
      </woot-tabs>
      <button
        v-if="isWideScreen && activeTabApp"
        type="button"
        class="shrink-0 px-3 h-7 me-3 text-xs rounded-lg bg-n-alpha-2 text-n-slate-12 hover:bg-n-alpha-3"
        @click="setSideApp(activeTabApp)"
      >
        {{ $t('CONVERSATION.DASHBOARD_APP_SIDE.SHOW_BESIDE') }}
      </button>
    </div>
    <div v-show="!activeIndex" class="flex h-full min-h-0 m-0">
      <MessagesView
        v-if="currentChat.id"
        :inbox-id="inboxId"
        :is-inbox-view="isInboxView"
      />
      <EmptyState
        v-if="!currentChat.id && !isInboxView"
        :is-on-expanded-layout="isOnExpandedLayout"
      />
      <aside
        v-if="sideApp && currentChat.id"
        class="flex flex-col w-[400px] 2xl:w-[460px] shrink-0 min-h-0 border-s border-n-weak bg-n-surface-1"
      >
        <div
          class="flex items-center justify-between h-10 px-3 border-b border-n-weak shrink-0"
        >
          <span class="text-sm font-medium text-n-slate-12 truncate">
            {{ sideApp.title }}
          </span>
          <button
            type="button"
            class="px-2 h-7 text-xs rounded-lg text-n-slate-11 hover:bg-n-alpha-2"
            @click="setSideApp(null)"
          >
            {{ $t('CONVERSATION.DASHBOARD_APP_SIDE.MOVE_TO_TAB') }}
          </button>
        </div>
        <DashboardAppFrame
          :key="currentChat.id + '-side-' + sideApp.id"
          class="flex-1 min-h-0"
          is-visible
          :config="sideApp.content"
          :position="dashboardApps.indexOf(sideApp)"
          :current-chat="currentChat"
        />
      </aside>
      <slot />
    </div>
    <DashboardAppFrame
      v-for="(dashboardApp, index) in tabApps"
      v-show="activeIndex - 1 === index"
      :key="currentChat.id + '-' + dashboardApp.id"
      :is-visible="activeIndex - 1 === index"
      :config="dashboardApp.content"
      :position="dashboardApps.indexOf(dashboardApp)"
      :current-chat="currentChat"
    />
  </div>
</template>
