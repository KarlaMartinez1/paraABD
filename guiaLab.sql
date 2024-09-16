SELECT F.ID, F.fecha, F.id_cliente, F.id_restaurante, SUM(P.precio) "Subtotal postre" FROM FACTURA F
    LEFT JOIN DETALLE_POSTRE DP ON DP.ID_FACTURA = F.ID
    LEFT JOIN POSTRE P ON P.ID = DP.ID_POSTRE
GROUP BY F.ID, F.fecha, F.id_cliente, F.id_restaurante;

CREATE OR REPLACE FUNCTION postre_consumido(p_id_factura INT)
RETURN FLOAT
AS v_subtotal NUMBEr(5,2);
BEGIN
    SELECT SUM(P.precio)
    INTO v_subtotal
    FROM FACTURA F
    LEFT JOIN DETALLE_POSTRE DP ON DP.ID_FACTURA = F.ID
    LEFT JOIN POSTRE P ON P.ID = DP.ID_POSTRE
    WHERE F.ID = p_id_factura;
RETURN v_subtotal;

END;

SELECT postre_consumido(1);


-- EJERCICIO 1 -----------------------------------------------------

SELECT F.ID, F.fecha, F.id_cliente, F.id_restaurante, SUM(P.precio) AS Subtotal_plato FROM FACTURA F
    LEFT JOIN DETALLE_PLATO DP ON DP.ID_FACTURA = F.ID
    LEFT JOIN PLATO P ON P.ID = DP.ID_PLATO
GROUP BY F.ID, F.fecha, F.id_cliente, F.id_restaurante;


CREATE OR REPLACE FUNCTION  platillos_consumidos(p_id_factura INT)
RETURN FLOAT
AS
v_subtotal FLOAT;
BEGIN
    SELECT SUM(P.precio)
    INTO v_subtotal
    FROM FACTURA F
    LEFT JOIN DETALLE_PLATO DP ON DP.ID_FACTURA = F.ID
    LEFT JOIN PLATO P ON P.ID = DP.ID_PLATO
    WHERE F.ID = p_id_factura;
    RETURN v_subtotal;
    
END;

SELECT platillos_consumidos(5);


---- EJERCICIO 2 -----------------------------------------

CREATE OR REPLACE TYPE t_facturas_row AS OBJECT(
    id_factura INT,
    fecha DATE,
    id_cliente INT,
    id_restaurante INT,
    subtotal_plato FLOAT,
    subtotal_postre FLOAT,
    total FLOAT
);

CREATE OR REPLACE TYPE t_facturas_collection AS TABLE OF t_facturas_row;

CREATE OR REPLACE FUNCTION subtotal_consumido(fecha_i IN DATE, fecha_f IN DATE)
RETURN t_facturas_collection
AS subt_consumido t_facturas_collection := t_facturas_collection();
BEGIN
    SELECT t_facturas_row(
    F.id, 
    F.fecha, 
    C.id, 
    R.id, 
    platillos_consumidos(F.id), 
    postre_consumido(F.id), 
    platillos_consumidos(F.id)+ postre_consumido(F.id)
    )
    BULK COLLECT INTO subt_consumido
    FROM FACTURA F 
    JOIN CLIENTE C ON F.id_cliente = C.id
    JOIN RESTAURANTE R ON F.id_restaurante = R.id
    WHERE F.fecha BETWEEN fecha_i AND fecha_f;
    
    RETURN subt_consumido;
END;

SELECT * FROM TABLE(subtotal_consumido(TO_DATE('01/01/2022','DD/MM/YYYY'), TO_DATE('30/01/2022', 'DD/MM/YYYY')));


------ EJERCICIO 3 -------------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE ganancias_restaurante (
    p_id_restaurante IN NUMBER,
    p_fecha_inicio IN VARCHAR2,
    p_fecha_fin IN VARCHAR2
) AS
    -- Definir un cursor para almacenar el resultado de la función
    CURSOR c_facturas IS
        SELECT *
        FROM TABLE(subtotal_consumido(TO_DATE(p_fecha_inicio, 'DD/MM/YYYY'), TO_DATE(p_fecha_fin, 'DD/MM/YYYY')))
        WHERE id_restaurante = p_id_restaurante;

    -- Variables para almacenar los valores del cursor
    v_id_factura FACTURA.id%TYPE;
    v_fecha FACTURA.fecha%TYPE;
    v_id_cliente CLIENTE.id%TYPE;
    v_id_restaurante RESTAURANTE.id%TYPE;
    v_total_platillos NUMBER;
    v_total_postres NUMBER;
    v_total_factura NUMBER;

BEGIN
    -- Intentar abrir el cursor y procesar los resultados
    OPEN c_facturas;

    LOOP
        FETCH c_facturas INTO v_id_factura, v_fecha, v_id_cliente, v_id_restaurante, v_total_platillos, v_total_postres, v_total_factura;
        EXIT WHEN c_facturas%NOTFOUND;
        
        -- Mostrar los resultados en consola
        DBMS_OUTPUT.PUT_LINE('Factura ID: ' || v_id_factura || 
                         ', Fecha: ' || v_fecha || 
                         ', Cliente ID: ' || v_id_cliente || 
                         ', Restaurante ID: ' || v_id_restaurante);
    
        DBMS_OUTPUT.PUT_LINE('Total Platillos: ' || v_total_platillos || 
                         ', Total Postres: ' || v_total_postres || 
                         ', Total Factura: ' || v_total_factura);
        DBMS_OUTPUT.PUT_LINE('-----------------------------------');
    END LOOP;

    -- Cerrar el cursor
    CLOSE c_facturas;

EXCEPTION
    -- Manejo de excepciones
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Ocurrió un error: ' || SQLERRM);
END ganancias_restaurante;

BEGIN
    ganancias_restaurante(1, '01/01/2022', '30/06/2022');
END;


---- EJERCICIO 4 ----------------------------------------------------

CREATE OR REPLACE TRIGGER verificar_estacion
BEFORE INSERT ON DETALLE_PLATO
FOR EACH ROW
DECLARE
    v_estacion VARCHAR2(25);
    v_fecha_factura DATE;
BEGIN
    -- Obtener la estación del menú al que pertenece el plato
    SELECT M.estacion
    INTO v_estacion
    FROM PLATO P
    JOIN MENU M ON P.id_menu = M.id
    WHERE P.id = :NEW.id_plato;

    -- Obtener la fecha de la factura
    SELECT F.fecha
    INTO v_fecha_factura
    FROM FACTURA F
    WHERE F.id = :NEW.id_factura;

    -- Verificar si la fecha de la factura corresponde a la estación del menú
    IF (v_estacion = 'primavera' AND NOT (v_fecha_factura BETWEEN TO_DATE('21/03', 'DD/MM') AND TO_DATE('21/06', 'DD/MM'))) THEN
        RAISE_APPLICATION_ERROR(-20001, 'El plato pertenece al menú de primavera, pero la fecha no corresponde a esta estación.');
    ELSIF (v_estacion = 'verano' AND NOT (v_fecha_factura BETWEEN TO_DATE('22/06', 'DD/MM') AND TO_DATE('23/09', 'DD/MM'))) THEN
        RAISE_APPLICATION_ERROR(-20002, 'El plato pertenece al menú de verano, pero la fecha no corresponde a esta estación.');
    ELSIF (v_estacion = 'otoño' AND NOT (v_fecha_factura BETWEEN TO_DATE('24/09', 'DD/MM') AND TO_DATE('21/12', 'DD/MM'))) THEN
        RAISE_APPLICATION_ERROR(-20003, 'El plato pertenece al menú de otoño, pero la fecha no corresponde a esta estación.');
    ELSIF (v_estacion = 'invierno' AND NOT (v_fecha_factura BETWEEN TO_DATE('22/12', 'DD/MM') AND TO_DATE('20/03', 'DD/MM'))) THEN
        RAISE_APPLICATION_ERROR(-20004, 'El plato pertenece al menú de invierno, pero la fecha no corresponde a esta estación.');
    END IF;

END;
/




-----------------------------------------------------------------

CREATE OR REPLACE TYPE points AS OBJECT
    (id_reserva INT,
    id_pasajero INT,
    pasajero VARCHAR2(64),
    identificacion VARCHAR2(20),
    costo FLOAT,
    puntos_costo INT,
    id_clase_reservada INT,
    puntos_clase INT,
    cantidad_servicios_extra INT,
    puntos_servicios_extra INT,
    puntos_total INT);

CREATE OR REPLACE TYPE puntos_reserva AS TABLE OF points;

CREATE OR REPLACE FUNCTION ejercicio2
RETURN puntos_reserva PIPELINED
AS
    reserva_count INT;
    clase_count INT;
    extra_count INT;
    total INT;
BEGIN
    FOR i IN (SELECT r.id, r.id_pasajero, p.nombre, p.identificacion, r.costo, r.id_clase, NVL(SUM(e.cantidad), 0) AS servicios_extra
            FROM Reserva r
            LEFT JOIN Pasajero p ON r.id_pasajero = p.id
            INNER JOIN Clase c ON r.id_clase = c.id
            LEFT JOIN Extra e ON e.id_reserva = r.id
            GROUP BY r.id, r.id_pasajero, r.costo, r.id_clase, p.nombre, p.identificacion
            ORDER BY r.id)
    LOOP
        IF i.costo < 60 THEN
            reserva_count := 2;
        ELSIF i.costo >= 60 AND i.costo <= 80 THEN
            reserva_count := 3;
        ELSE
            reserva_count := 5;
        END IF;
        
        IF i.id_clase = 1 THEN
            clase_count := 5;
        ELSIF i.id_clase = 2 THEN
            clase_count := 6;
        ELSIF i.id_clase = 3 THEN
            clase_count := 7;
        END IF;
        
        extra_count := i.servicios_extra * 5;
        total := reserva_count + clase_count + extra_count;
        
        
        PIPE ROW(points(i.id, i.id_pasajero, i.nombre, i.identificacion, i.costo, reserva_count, i.id_clase, clase_count,
        i.servicios_extra, extra_count, total));
    END LOOP;
    RETURN;
END;

SELECT * FROM TABLE(ejercicio2);


---------------------------------------

CREATE OR REPLACE TYPE passenger AS OBJECT 
    (id NUMBER, 
    nombre VARCHAR2(50), 
    identificacion VARCHAR2(64), 
    fecha_nacimiento DATE, 
    reservas INT,
    percent FLOAT);

CREATE OR REPLACE TYPE pasajeros AS TABLE OF passenger;

CREATE OR REPLACE FUNCTION ejercicio1 (fecha_i IN DATE, fecha_f IN DATE)
RETURN pasajeros PIPELINED
AS
    p_percent float;
    total int;
BEGIN
    SELECT COUNT(r.id)
    INTO total
    FROM Pasajero p
    LEFT JOIN Reserva r ON p.id = r.id_pasajero
    WHERE r.fecha_reserva BETWEEN fecha_i AND fecha_f;
    
    FOR i IN (SELECT p.id, p.nombre, p.identificacion, p.fecha_nacimiento, COUNT(r.id) AS reservas
    FROM Pasajero p
    LEFT JOIN Reserva r ON p.id = r.id_pasajero
    AND r.fecha_reserva BETWEEN fecha_i AND fecha_f
    GROUP BY p.id, p.nombre, p.identificacion, p.fecha_nacimiento
    ORDER BY p.id
    )
    LOOP
        p_percent := ROUND((i.reservas * 100) / total, 2);
        PIPE ROW(passenger(i.id, i.nombre, i.identificacion, i.fecha_nacimiento, i.reservas, p_percent));
    END LOOP;
    RETURN;
END;

SELECT * FROM TABLE(ejercicio1(TO_DATE('2023-04-05', 'YYYY-MM-DD'), TO_DATE('2023-04-18', 'YYYY-MM-DD')));



