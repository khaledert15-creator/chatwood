import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import ConversationView from './ConversationView.vue';

describe('ConversationView', () => {
  describe('findConversation', () => {
    it('finds a conversation outside the filtered conversation list', () => {
      const conversation = {
        id: 42,
        status: 'resolved',
        messages: [],
      };
      const getConversationById = vi.fn().mockReturnValue(conversation);

      const result = ConversationView.methods.findConversation.call({
        conversationId: '42',
        chatList: [],
        getConversationById,
      });

      expect(getConversationById).toHaveBeenCalledWith(42);
      expect(result).toBe(conversation);
    });
  });

  describe('fetchConversationIfUnavailable', () => {
    it('activates a conversation explicitly after fetching it', async () => {
      const setActiveChat = vi.fn();
      const dispatch = vi.fn().mockResolvedValue();
      const context = {
        conversationId: '42',
        findConversation: vi.fn().mockReturnValue(undefined),
        setActiveChat,
        $store: { dispatch },
      };

      await ConversationView.methods.fetchConversationIfUnavailable.call(
        context
      );

      expect(dispatch).toHaveBeenCalledWith('getConversation', '42');
      expect(setActiveChat).toHaveBeenCalledOnce();
    });

    it('activates a conversation already in the store without fetching it', async () => {
      const setActiveChat = vi.fn();
      const dispatch = vi.fn();
      const context = {
        conversationId: 42,
        findConversation: vi.fn().mockReturnValue({ id: 42 }),
        setActiveChat,
        $store: { dispatch },
      };

      await ConversationView.methods.fetchConversationIfUnavailable.call(
        context
      );

      expect(dispatch).not.toHaveBeenCalled();
      expect(setActiveChat).toHaveBeenCalledOnce();
    });
  });

  describe('setActiveChat', () => {
    it('scrolls to a loaded search result without reloading the active conversation', () => {
      const dispatch = vi.fn();
      const emit = vi.spyOn(emitter, 'emit');
      const conversation = {
        id: 42,
        messages: [{ id: 99 }],
      };
      const context = {
        conversationId: 42,
        currentChat: conversation,
        findConversation: () => conversation,
        $route: { query: { messageId: '99' } },
        $store: { dispatch },
      };

      ConversationView.methods.setActiveChat.call(context);

      expect(dispatch).not.toHaveBeenCalled();
      expect(emit).toHaveBeenCalledWith(BUS_EVENTS.SCROLL_TO_MESSAGE, {
        messageId: '99',
      });
    });

    it('loads an unavailable target message in the active conversation', async () => {
      const dispatch = vi.fn().mockResolvedValue();
      const emit = vi.spyOn(emitter, 'emit');
      const conversation = {
        id: 42,
        messages: [{ id: 100 }],
      };
      const context = {
        conversationId: 42,
        currentChat: conversation,
        findConversation: () => conversation,
        $route: { query: { messageId: '50' } },
        $store: { dispatch },
      };

      ConversationView.methods.setActiveChat.call(context);
      await Promise.resolve();

      expect(dispatch).toHaveBeenCalledWith('setActiveChat', {
        data: conversation,
        after: '50',
      });
      expect(emit).toHaveBeenCalledWith(BUS_EVENTS.SCROLL_TO_MESSAGE, {
        messageId: '50',
      });
    });
  });
});
