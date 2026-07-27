import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import ConversationView from './ConversationView.vue';

describe('ConversationView', () => {
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
