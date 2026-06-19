/* global axios */
import ApiClient from './ApiClient';

class CashTransactionsAPI extends ApiClient {
  constructor() {
    super('cash_transactions', { accountScoped: true });
  }

  list(params = {}) {
    return axios.get(this.url, { params });
  }

  summary(params = {}) {
    return axios.get(`${this.url}/summary`, { params });
  }

  create(data) {
    return axios.post(this.url, data);
  }

  del(id) {
    return axios.delete(`${this.url}/${id}`);
  }
}

class CommissionsAPI extends ApiClient {
  constructor() {
    super('commissions', { accountScoped: true });
  }

  list(params = {}) {
    return axios.get(this.url, { params });
  }

  summary(params = {}) {
    return axios.get(`${this.url}/summary`, { params });
  }

  update(id, data) {
    return axios.patch(`${this.url}/${id}`, data);
  }
}

export const cashTransactionsAPI = new CashTransactionsAPI();
export const commissionsAPI = new CommissionsAPI();
