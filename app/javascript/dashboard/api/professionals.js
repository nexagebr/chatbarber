/* global axios */
import ApiClient from './ApiClient';

class ProfessionalsAPI extends ApiClient {
  constructor() { super('professionals', { accountScoped: true }); }
  list()                  { return axios.get(this.url); }
  get(id)                 { return axios.get(`${this.url}/${id}`); }
  create(data)            { return axios.post(this.url, data); }
  update(id, data)        { return axios.patch(`${this.url}/${id}`, data); }
  del(id)                 { return axios.delete(`${this.url}/${id}`); }
  activateAgent(agentId, active) { return axios.post(`${this.url}/activate_agent`, { agent_id: agentId, active }); }
  setSchedules(id, schedules)    { return axios.put(`${this.url}/${id}/schedules`, { schedules }); }
  getBlockedDates(id)            { return axios.get(`${this.url}/${id}/blocked_dates`); }
  addBlockedDate(id, data)       { return axios.post(`${this.url}/${id}/blocked_dates`, data); }
  delBlockedDate(profId, id)     { return axios.delete(`${this.url}/${profId}/blocked_dates/${id}`); }
  getBreaks(id)                  { return axios.get(`${this.url}/${id}/breaks`); }
  addBreak(id, data)             { return axios.post(`${this.url}/${id}/breaks`, data); }
  delBreak(profId, breakId)      { return axios.delete(`${this.url}/${profId}/breaks`, { params: { break_id: breakId } }); }
}

class BranchesAPI extends ApiClient {
  constructor() { super('branches', { accountScoped: true }); }
  list()            { return axios.get(this.url); }
  get(id)           { return axios.get(`${this.url}/${id}`); }
  create(data)      { return axios.post(this.url, data); }
  update(id, data)  { return axios.patch(`${this.url}/${id}`, data); }
  del(id)           { return axios.delete(`${this.url}/${id}`); }
  setSchedules(id, schedules) { return axios.put(`${this.url}/${id}/schedules`, { schedules }); }
  getHolidays(id)             { return axios.get(`${this.url}/${id}/holidays`); }
  addHoliday(id, data)        { return axios.post(`${this.url}/${id}/holidays`, data); }
  delHoliday(id, hid)         { return axios.delete(`${this.url}/${id}/holidays/${hid}`); }
}

class AvailabilityAPI extends ApiClient {
  constructor() { super('availability', { accountScoped: true }); }
  get(date, professionalIds, branchId) {
    return axios.get(this.url, { params: { date, professional_ids: professionalIds, branch_id: branchId } });
  }
}

export const professionalsAPI = new ProfessionalsAPI();
export const branchesAPI = new BranchesAPI();
export const availabilityAPI = new AvailabilityAPI();
