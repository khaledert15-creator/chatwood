/* global axios */
import ApiClient from './ApiClient';

class WhatsappCostsAPI extends ApiClient {
  constructor() {
    super('whatsapp_costs', { accountScoped: true, apiVersion: 'v2' });
  }

  getReport({ month, timezone, signal }) {
    return axios.get(this.url, { params: { month, timezone }, signal });
  }
}

export default new WhatsappCostsAPI();
