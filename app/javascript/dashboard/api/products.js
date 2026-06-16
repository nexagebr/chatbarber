/* global axios */
import ApiClient from './ApiClient';

class ProductsAPI extends ApiClient {
  constructor() {
    super('products', { accountScoped: true });
  }

  list(search) {
    return axios.get(`${this.url}`, { params: { search } });
  }

  getOne(id) {
    return axios.get(`${this.url}/${id}`);
  }

  create(data) {
    return axios.post(`${this.url}`, data);
  }

  update(id, data) {
    return axios.patch(`${this.url}/${id}`, data);
  }

  del(id) {
    return axios.delete(`${this.url}/${id}`);
  }
}

export default new ProductsAPI();
