/* global axios */
import ApiClient from './ApiClient';

class AgentPerformanceAPI extends ApiClient {
  constructor() {
    super('agent_performance', { accountScoped: true });
  }

  getDaily({ agentId, date }) {
    return axios.get(`${this.url}/daily`, {
      params: { agent_id: agentId, date },
    });
  }

  getTargets() {
    return axios.get(`${this.url}/targets`);
  }

  createTarget(target) {
    return axios.post(`${this.url}/targets`, { target });
  }
}

export default new AgentPerformanceAPI();
