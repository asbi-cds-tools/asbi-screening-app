<template>
  <v-app id="app">
    <SurveyComponent/>
  </v-app>
</template>

<script>
import SurveyComponent from './components/SurveyComponent.vue'

export default {
  name: 'App',
  components: {
    SurveyComponent
  }
}
</script>
