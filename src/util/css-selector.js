//dynamically load css for a questionnaire
export function getInstrumentCSS(screeningInstrument) {
  if (!screeningInstrument) throw new Error("No screening instrument specified for stylesheet.");
  return import(`../style/instruments/${screeningInstrument.toLowerCase()}.scss`);
}
