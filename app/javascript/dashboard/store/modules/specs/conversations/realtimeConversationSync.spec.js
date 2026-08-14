import axios from 'axios';
import actions, {
  resetRealtimeConversationHydration,
} from '../../conversations/actions';
import { mutations } from '../../conversations';
import types from '../../../mutation-types';

global.axios = axios;
vi.mock('axios');

const makeConversation = (overrides = {}) => ({
  id: 1,
  account_id: 1,
  inbox_id: 1,
  status: 'open',
  labels: [],
  messages: [],
  last_activity_at: 100,
  created_at: 100,
  updated_at: 100,
  meta: {
    sender: { id: 10, name: 'Customer' },
    assignee: null,
    team: null,
    ...overrides.meta,
  },
  ...overrides,
});

const createHarness = ({
  conversations = [],
  filters = {},
  appliedFilters = [],
  route = { name: 'home', params: {} },
  activeFolder = null,
  currentUserId = 7,
} = {}) => {
  const state = {
    allConversations: conversations,
    appliedFilters,
    conversationFilters: {
      status: 'open',
      assigneeType: 'all',
      sortBy: 'last_activity_at_desc',
      ...filters,
    },
    chatSortFilter: 'last_activity_at_desc',
    selectedChatId: null,
  };
  const rootState = {
    route,
    customViews: { activeConversationFolder: activeFolder },
  };
  const rootGetters = {
    getCurrentAccountId: 1,
    getCurrentUser: { id: currentUserId },
    getCurrentUserID: currentUserId,
  };
  const commit = vi.fn((type, payload) => {
    const mutation = mutations[type];
    if (mutation) mutation(state, payload);
  });
  let context;
  const dispatch = vi.fn((type, payload) => {
    if (actions[type]) return actions[type](context, payload);
    return Promise.resolve();
  });
  context = { state, rootState, rootGetters, commit, dispatch };

  return { state, rootState, rootGetters, commit, dispatch, context };
};

const sync = (harness, conversation, source = 'conversation_created') =>
  actions.syncRealtimeConversation(harness.context, {
    conversation,
    source,
  });

describe('real-time conversation list regression', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    resetRealtimeConversationHydration();
  });

  it('Test 1: shows a new conversation from the current inbox immediately', () => {
    const harness = createHarness({ filters: { inboxId: 1 } });

    expect(sync(harness, makeConversation())).toBe(true);
    expect(harness.state.allConversations.map(({ id }) => id)).toEqual([1]);
  });

  it('Test 2: does not show a conversation from another inbox', () => {
    const harness = createHarness({ filters: { inboxId: 1 } });

    expect(sync(harness, makeConversation({ inbox_id: 2 }))).toBe(false);
    expect(harness.state.allConversations).toEqual([]);
  });

  it('Test 3: keeps the team filter authoritative', () => {
    const harness = createHarness({ filters: { teamId: 3 } });

    sync(harness, makeConversation({ meta: { team: { id: 4 } } }));
    sync(
      harness,
      makeConversation({ id: 2, meta: { team: { id: 3 } } }),
      'team'
    );

    expect(harness.state.allConversations.map(({ id }) => id)).toEqual([2]);
  });

  it('Test 4: keeps the label filter authoritative', () => {
    const harness = createHarness({ filters: { labels: ['priority'] } });

    sync(harness, makeConversation({ labels: ['other'] }));
    sync(harness, makeConversation({ id: 2, labels: ['priority'] }));

    expect(harness.state.allConversations.map(({ id }) => id)).toEqual([2]);
  });

  it('keeps advanced filters and saved conversation folders authoritative', () => {
    const teamFilter = [
      {
        attribute_key: 'team_id',
        filter_operator: 'equal_to',
        values: { id: 3, name: 'Support' },
        query_operator: 'and',
      },
    ];
    const advancedFilterHarness = createHarness({
      appliedFilters: teamFilter,
    });
    const folderHarness = createHarness({
      activeFolder: { query: { payload: teamFilter } },
    });
    const matchingConversation = makeConversation({
      meta: { team: { id: 3, name: 'Support' } },
    });
    const excludedConversation = makeConversation({
      id: 2,
      meta: { team: { id: 4, name: 'Sales' } },
    });

    sync(advancedFilterHarness, excludedConversation);
    sync(advancedFilterHarness, matchingConversation);
    sync(folderHarness, excludedConversation);
    sync(folderHarness, matchingConversation);

    expect(
      advancedFilterHarness.state.allConversations.map(({ id }) => id)
    ).toEqual([1]);
    expect(folderHarness.state.allConversations.map(({ id }) => id)).toEqual([
      1,
    ]);
  });

  it('Test 5: only a mention event can enter the mentions conversation type', () => {
    const harness = createHarness({
      filters: { conversationType: 'mention' },
      route: { name: 'conversation_mentions', params: {} },
    });
    const conversation = makeConversation();

    expect(sync(harness, conversation)).toBe(false);
    expect(sync(harness, conversation, 'mention')).toBe(true);
    expect(harness.state.allConversations).toHaveLength(1);
  });

  it('Test 6: assigned-to-me only accepts the current agent conversations', () => {
    const harness = createHarness({ filters: { assigneeType: 'me' } });

    sync(
      harness,
      makeConversation({ meta: { assignee: { id: 8 } } }),
      'assignee'
    );
    sync(
      harness,
      makeConversation({ id: 2, meta: { assignee: { id: 7 } } }),
      'assignee'
    );

    expect(harness.state.allConversations.map(({ id }) => id)).toEqual([2]);
  });

  it('Test 7: unassigned only accepts conversations without an assignee', () => {
    const harness = createHarness({ filters: { assigneeType: 'unassigned' } });

    sync(
      harness,
      makeConversation({ meta: { assignee: { id: 7 } } }),
      'assignee'
    );
    sync(harness, makeConversation({ id: 2 }));

    expect(harness.state.allConversations.map(({ id }) => id)).toEqual([2]);
  });

  it('Test 8: a duplicate event never duplicates a conversation', () => {
    const harness = createHarness();
    const conversation = makeConversation();

    sync(harness, conversation);
    sync(harness, { ...conversation, updated_at: 101 });

    expect(harness.state.allConversations).toHaveLength(1);
  });

  it('Test 9: a new message moves its conversation to the correct order', () => {
    const harness = createHarness({
      conversations: [
        makeConversation({ id: 1, last_activity_at: 200 }),
        makeConversation({ id: 2, last_activity_at: 100 }),
      ],
    });

    harness.commit(types.UPDATE_CONVERSATION_LAST_ACTIVITY, {
      conversationId: 2,
      lastActivityAt: 300,
    });

    expect(harness.state.allConversations.map(({ id }) => id)).toEqual([2, 1]);
  });

  it('Test 10: a filter change during hydration cannot insert the old scope', async () => {
    let resolveRequest;
    axios.get.mockReturnValue(
      new Promise(resolve => {
        resolveRequest = resolve;
      })
    );
    const harness = createHarness({ filters: { inboxId: 1 } });
    const hydration = actions.hydrateConversationFromRealtime(harness.context, {
      conversationId: 1,
      message: { id: 11, conversation_id: 1 },
    });

    harness.state.conversationFilters = {
      ...harness.state.conversationFilters,
      inboxId: 2,
    };
    resolveRequest({ data: makeConversation({ inbox_id: 1 }) });

    await expect(hydration).resolves.toBe(false);
    expect(harness.state.allConversations).toEqual([]);
  });
});

describe('real-time hydration race and request control', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    resetRealtimeConversationHydration();
  });

  it('coalesces rapid messages into one API request and replays every message', async () => {
    let resolveRequest;
    axios.get.mockReturnValue(
      new Promise(resolve => {
        resolveRequest = resolve;
      })
    );
    const harness = createHarness();
    const first = actions.hydrateConversationFromRealtime(harness.context, {
      conversationId: 1,
      message: {
        id: 11,
        conversation_id: 1,
        conversation: { last_activity_at: 101 },
      },
    });
    const second = actions.hydrateConversationFromRealtime(harness.context, {
      conversationId: 1,
      message: {
        id: 12,
        conversation_id: 1,
        conversation: { last_activity_at: 102 },
      },
    });

    expect(axios.get).toHaveBeenCalledTimes(1);
    resolveRequest({ data: makeConversation() });
    await Promise.all([first, second]);

    expect(harness.state.allConversations).toHaveLength(1);
    expect(
      harness.dispatch.mock.calls.filter(([type]) => type === 'addMessage')
    ).toHaveLength(2);
  });

  it('does not fetch when conversation.created wins the event race', async () => {
    const harness = createHarness();
    sync(harness, makeConversation());

    await actions.hydrateConversationFromRealtime(harness.context, {
      conversationId: 1,
      message: { id: 11, conversation_id: 1 },
    });

    expect(axios.get).not.toHaveBeenCalled();
    expect(harness.state.allConversations).toHaveLength(1);
  });

  it('backs off repeated hydration misses in the same filter scope', async () => {
    axios.get.mockResolvedValue({ data: makeConversation({ inbox_id: 2 }) });
    const harness = createHarness({ filters: { inboxId: 1 } });

    await actions.hydrateConversationFromRealtime(harness.context, {
      conversationId: 1,
      message: { id: 11, conversation_id: 1 },
    });
    await actions.hydrateConversationFromRealtime(harness.context, {
      conversationId: 1,
      message: { id: 12, conversation_id: 1 },
    });

    expect(axios.get).toHaveBeenCalledTimes(1);
  });
});
