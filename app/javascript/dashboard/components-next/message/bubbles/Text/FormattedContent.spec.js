import { mount } from '@vue/test-utils';
import { ref } from 'vue';

import FormattedContent from './FormattedContent.vue';

vi.mock('../../provider.js', () => ({
  useMessageContext: () => ({ variant: ref('user') }),
}));

const mountFormattedContent = content =>
  mount(FormattedContent, {
    props: { content },
    global: {
      directives: {
        dompurifyHtml: (element, binding) => {
          element.innerHTML = binding.value;
        },
      },
    },
  });

describe('FormattedContent', () => {
  it.each([
    'رسالة قصيرة',
    'رسالة طويلة تحتوي على أرقام 123 وإيموجي 👋\n\n- السطر الأول\n- السطر الثاني',
  ])('applies readable RTL typography to Arabic content', content => {
    const wrapper = mountFormattedContent(content);
    const message = wrapper.get('span');

    expect(message.attributes('dir')).toBe('rtl');
    expect(message.classes()).toContain('text-right');
    expect(message.classes()).toContain('leading-normal');
    expect(message.classes()).toContain('[&_p]:my-0');
    expect(message.classes()).toContain('sm:leading-relaxed');
    expect(message.classes()).toContain('sm:[&_p]:my-1');
  });

  it('keeps English content styling unchanged', () => {
    const wrapper = mountFormattedContent('A short English message.');
    const message = wrapper.get('span');

    expect(message.attributes('dir')).toBeUndefined();
    expect(message.classes()).not.toContain('leading-normal');
    expect(message.classes()).not.toContain('[&_p]:my-0');
    expect(message.classes()).not.toContain('sm:leading-relaxed');
    expect(message.classes()).not.toContain('sm:[&_p]:my-1');
  });
});
