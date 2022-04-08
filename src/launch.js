import Vue from 'vue'
import vuetify from '@/plugins/vuetify'
import Launch from './Launch.vue'

Vue.config.productionTip = false

new Vue({
  vuetify,
  render: h => h(Launch),
}).$mount('#launch')
