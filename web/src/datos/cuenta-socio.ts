/* ===========================================================================
   A dónde deposita el socio.

   Está en un archivo aparte y solo, porque es lo único de esta app que hay
   que cambiar a mano antes de vender de verdad: hoy son datos de relleno.
   Cuando SOCIO tenga su cuenta, se reemplazan aquí y en ningún otro sitio.

   No es un secreto: un número de cuenta para recibir depósitos es justo lo
   que el socio tiene que ver. Por eso vive en el código de la pantalla y no
   en una variable de entorno.
   =========================================================================== */

export interface CuentaSocio {
  banco: string;
  numero: string;
  cci: string;
  titular: string;
  /** El celular de Yape o Plin al que se deposita. */
  billetera: string;
  /** false mientras sean datos de relleno: la pantalla lo advierte. */
  esReal: boolean;
}

export const CUENTA_SOCIO: CuentaSocio = {
  banco: "BCP Soles",
  numero: "193-XXXXXXX-0-XX",
  cci: "002-193-XXXXXXXXXX",
  titular: "SOCIO SAC",
  billetera: "9XX XXX XXX",
  esReal: false,
};
