/* global axios */
import ApiClient from './ApiClient';

class AppointmentsAPI extends ApiClient {
  constructor() {
    super('appointments', { accountScoped: true });
  }

  list(params = {}) {
    return axios.get(this.url, { params, timeout: 10000 });
  }

  create(data) {
    return axios.post(this.url, data, { timeout: 15000 });
  }

  update(id, data) {
    return axios.patch(`${this.url}/${id}`, data, { timeout: 15000 });
  }

  del(id) {
    return axios.delete(`${this.url}/${id}`, { timeout: 10000 });
  }
}

class ServicesAPI extends ApiClient {
  constructor() {
    super('services', { accountScoped: true });
  }

  list() {
    return axios.get(this.url);
  }

  create(data) {
    return axios.post(this.url, data);
  }

  update(id, data) {
    return axios.patch(`${this.url}/${id}`, data);
  }

  del(id) {
    return axios.delete(`${this.url}/${id}`);
  }
}

export const appointmentsAPI = new AppointmentsAPI();
export const servicesAPI = new ServicesAPI();
