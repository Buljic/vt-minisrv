package org.demo;

import com.sun.net.httpserver.HttpServer;

import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class App {
    public static void main(String[] args) throws Exception {
        boolean vt = Boolean.parseBoolean(System.getProperty("vt", "false"));

        // Pool za HTTP dispatch (da ne "zaključa" sve threadove)
        ExecutorService serverPool = Executors.newFixedThreadPool(50);
        // Pool za stvarne zadatke (I/O ili CPU)
        ExecutorService workerPool = vt
                ? Executors.newVirtualThreadPerTaskExecutor()
                : Executors.newFixedThreadPool(200);

        HttpServer svr = HttpServer.create(new InetSocketAddress(8080), 0);
        svr.setExecutor(serverPool);

        // I/O-bound endpoint
        svr.createContext("/io", ex -> {
            workerPool.submit(() -> {
                try {
                    Thread.sleep(50); // simulacija I/O
                    byte[] ok = "OK".getBytes();
                    ex.sendResponseHeaders(200, ok.length);
                    try (var out = ex.getResponseBody()) {
                        out.write(ok);
                    }
                } catch (InterruptedException ignored) {
                } catch (IOException ioe) {
                    ioe.printStackTrace();
                }
            });
        });

        // CPU-bound endpoint
        svr.createContext("/cpu", ex -> {
            workerPool.submit(() -> {
                pbkdf2();
                try {
                    byte[] ok = "OK".getBytes();
                    ex.sendResponseHeaders(200, ok.length);
                    try (var out = ex.getResponseBody()) {
                        out.write(ok);
                    }
                } catch (IOException ioe) {
                    ioe.printStackTrace();
                }
            });
        });

        svr.start();
        System.out.println("MiniServer  vt=" + vt);

        // Drži JVM živim dok ne pritisneš Ctrl+C
        synchronized (App.class) {
            App.class.wait();
        }
    }

    private static void pbkdf2() {
        try {
            var spec = new PBEKeySpec("x".toCharArray(), new byte[8], 20_000, 256);
            SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec);
        } catch (Exception ignored) {}
    }
}
