<template>
  <v-app id="app">
    <Header :title="title" :patient="patient" v-if="patient"></Header>
    <Survey
      :client="client"
      :patient="patient"
      :authError="getError()"
      @finished="finished"
    />
  </v-app>
</template>
<script>
import FHIR from "fhirclient";
import "survey-vue/modern.css";
import "./style/app.scss";
import Header from "./components/Header";
import Survey from "./components/Survey";
import {
  fetchEnvData,
  getEnv,
  getErrorText,
  queryPatientIdKey,
} from "./util/util";

const ENV_TITLE = getEnv("VUE_APP_TITLE");

export default {
  name: "App",
  components: {
    Header,
    Survey,
  },
  data() {
    return {
      title: ENV_TITLE ? ENV_TITLE : "",
      client: null,
      patient: null,
      error: "",
      ready: false,
    };
  },
  created() {
    fetchEnvData();
  },
  async mounted() {
    try {
      this.client = await this.setAuthClient();
    } catch (e) {
      this.error = e;
    }
    if (!this.error) {
      try {
        this.patient = await this.setPatient().catch((e) => (this.error = e));
      } catch (e) {
        this.error = e;
      }
      if (!this.error && (!this.patient || !this.patient.id)) {
        this.error = "No valid patient is set.";
      }
    }
  },
  methods: {
    async setAuthClient() {
      let authClient;
      // Wait for authorization
      try {
        authClient = await FHIR.oauth2.ready();
      } catch (e) {
        throw new Error(e);
      }
      return authClient;
    },
    async setPatient() {
      //patient id was coming from url query string parameter and stored as sessionStorage item
      let queryPatientId = sessionStorage.getItem(queryPatientIdKey);
      if (queryPatientId) {
        console.log(
          "Patient id unavailable from client object. Using stored patient id ",
          queryPatientId
        );
        return this.client.request("/Patient/" + queryPatientId);
      }
      let pt;
      //set patient
      try {
        pt = await this.client.patient.read().then((pt) => {
          return pt;
        });
      } catch (e) {
        throw new Error(e);
      }
      return pt;
    },
    getError() {
      return getErrorText(this.error);
    },
    finished(data) {
      if (!data) return;
      if (data.title)
        this.title = data.title;
    },
  },
};
</script>