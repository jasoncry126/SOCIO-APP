-- Vuelca la ganancia del socio que calcula la BASE para una batería de casos.
-- La compara con la que calcula app/socio-precios.js el script de al lado.
-- Salida cruda: publico|mayorista|nivel|ganancia
select p.pub, p.may, n.nivel, ganancia_unitaria(p.pub, p.may, n.nivel)
  from (values
          (175.00, 129.67), (175.00, 120.00), (175.00, 140.00), (175.00, 100.00),
          (300.00, 210.00), (115.00,  80.00), (100.00,  10.00), (175.00, 174.00),
          ( 60.00,  40.00), (245.00, 180.00), ( 99.90,  70.15), (1000.00, 700.00),
          ( 12.50,   9.00), (175.00, 129.68), (175.00, 129.66), ( 33.33,  24.00)
       ) as p(pub, may),
       (values ('bronce'),('plata'),('oro'),('diamante')) as n(nivel)
 order by p.pub, p.may, n.nivel;
