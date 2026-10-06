/* global axios */
import ApiClient from './ApiClient';

class WhatsappCostsAPI extends ApiClient {
  constructor() {
    super('whatsapp_costs', { accountScoped: true, apiVersion: 'v2' });
  }

  getReport({ month, timezone, signal }) {
    return axios.get(this.url, { params: { month, timezone }, signal });
  }

  getPaidMessages({
    month,
    timezone,
    classification,
    inboxId,
    beforeId,
    signal,
  }) {
    return axios.get(`${this.url}/paid_messages`, {
      params: {
        month,
        timezone,
        classification,
        inbox_id: inboxId || undefined,
        before_id: beforeId || undefined,
      },
      signal,
    });
  }
}

export default new WhatsappCostsAPI();
