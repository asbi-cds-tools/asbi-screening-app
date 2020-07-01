import Vue from 'vue'
import Launch from './Launch.vue'

Vue.config.productionTip = false

new Vue({
  render: h => h(Launch),
}).$mount('#launch')
