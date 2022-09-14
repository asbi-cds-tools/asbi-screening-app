//dynamically load css for a questionnaire
export function getInstrumentCSS() {
  let screeningInstrument = process.env.VUE_APP_SCREENING_INSTRUMENT ? 
  process.env.VUE_APP_SCREENING_INSTRUMENT.toLowerCase() : "";
  return import(`../style/instruments/${screeningInstrument}.scss`);
}
