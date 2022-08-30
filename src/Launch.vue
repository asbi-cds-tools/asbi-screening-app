<template>
  <v-app id="launch">
    <div class="pa-8" v-if="!error">
      <v-progress-circular
        :value="100"
        indeterminate
        color="primary"
        class="mr-1"
      ></v-progress-circular>
      Loading...
    </div>
    <div class="pa-8" v-if="error">
      <v-alert color="error" v-if="error" dark>
        Error launching the application.
        <div v-html="getError()"></div>
      </v-alert>
    </div>
  </v-app>
</template>

<script>
import FHIR from "fhirclient";
import {
  fetchEnvData,
  getEnv,
  getErrorText,
  queryPatientIdKey,
} from "./util/util.js";

const urlParams = new URLSearchParams(window.location.search);
const patientId = urlParams.get("patient");
console.log("patient id from url query string: ", patientId);

export default {
  name: "Launch",
  data() {
    return {
      error: "",
    };
  },
  created() {
    fetchEnvData();
  },
  mounted() {
    let self = this;

    sessionStorage.removeItem(queryPatientIdKey); //remove any stored patient id before launching the app
    let launchContextURL = "launch-context.json";
    let envLaunchContextURL = getEnv("VUE_APP_CONF_API_URL");
    if (envLaunchContextURL) launchContextURL = envLaunchContextURL;
    console.log("launch context url: ", launchContextURL);

    fetch(launchContextURL, {
      // include cookies in request
      credentials: "include",
    })
      .then((result) => {
        if (!result.ok) {
          throw new Error(result.status.toString());
        }
        return result.json();
      })
      .then((json) => {
        if (patientId) {
          //only do this IF patient id comes from url queryString
          json.patientId = patientId;
          sessionStorage.setItem(queryPatientIdKey, patientId);
        }
        //allow auth scopes to be updated via environment variable
        //see https://build.fhir.org/ig/HL7/smart-app-launch/scopes-and-launch-context.html
        const envAuthScopes = getEnv("VUE_APP_AUTH_SCOPES");
        if (envAuthScopes) json.scope = envAuthScopes;

        console.log("launch context json ", json);
        FHIR.oauth2.authorize(json).catch((e) => {
          self.error = e;
        });
      })
      .catch((e) => {
        self.error = e;
        console.log("launch error ", e);
      });
  },
  methods: {
    getError() {
      return getErrorText(this.error);
    },
  },
};
</script>
