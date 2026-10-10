package ru.svidetel;

import net.fabricmc.api.ModInitializer;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.fabricmc.fabric.api.networking.v1.ServerPlayConnectionEvents;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.level.Level;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * СВИДЕТЕЛЬ — ранний игровой прототип для Minecraft 26.3 / Fabric.
 *
 * Реализованы базовые скрытые параметры рассудка и внимания, а также редкие
 * атмосферные сообщения. Эти параметры пока существуют в памяти текущего
 * серверного сеанса и не сохраняются после перезапуска.
 */
public final class SvidetelMod implements ModInitializer {
    public static final String MOD_ID = "svidetel";

    private static final Map<UUID, HorrorState> STATES = new ConcurrentHashMap<>();
    private static long ticks;

    @Override
    public void onInitialize() {
        ServerTickEvents.END_SERVER_TICK.register(server -> {
            ticks++;

            for (ServerPlayer player : server.getPlayerList().getPlayers()) {
                if (player.isSpectator() || player.isCreative()) {
                    continue;
                }

                HorrorState state = STATES.computeIfAbsent(
                    player.getUUID(), ignored -> new HorrorState()
                );

                Level level = player.level();
                long dayTime = Math.floorMod(level.getDayTime(), 24000L);
                boolean night = dayTime >= 13000L && dayTime <= 23000L;
                boolean underground = !level.canSeeSky(player.blockPosition());

                // Рассудок меняется раз в 5 секунд, а не каждый игровой тик.
                if (ticks % 100L == 0L) {
                    if (night || underground) {
                        state.sanity = Math.max(0, state.sanity - 1);
                    } else if (level.getBrightness(
                        net.minecraft.world.level.LightLayer.SKY,
                        player.blockPosition()
                    ) > 8) {
                        state.sanity = Math.min(100, state.sanity + 1);
                    }
                }

                if (ticks % 100L == 0L) {
                    state.attention = Math.max(0, state.attention - 2);
                }

                if (ticks % 40L == 0L && player.isSprinting()) {
                    // Спринт привлекает внимание, но уровень не должен мгновенно достигать максимума.
                    state.attention = Math.min(100, state.attention + 1);
                }

                if (ticks % 1200L == 0L && state.sanity < 45
                    && player.getRandom().nextInt(4) == 0) {
                    player.displayClientMessage(
                        Component.literal("§8Кажется, за спиной кто-то стоит..."),
                        true
                    );
                }

                if (ticks % 2400L == 0L && state.sanity < 25
                    && player.getRandom().nextInt(3) == 0) {
                    player.displayClientMessage(
                        Component.literal("§7Не оборачивайся."),
                        false
                    );
                }
            }
        });

        // Не оставляем состояние игрока в памяти после выхода с сервера.
        ServerPlayConnectionEvents.DISCONNECT.register(
            (handler, server) -> STATES.remove(handler.player.getUUID())
        );
    }

    /** Поднимает скрытый уровень внимания, например после шума или боя. */
    public static void raiseAttention(ServerPlayer player, int amount) {
        HorrorState state = STATES.computeIfAbsent(
            player.getUUID(), ignored -> new HorrorState()
        );
        state.attention = Math.min(100, state.attention + Math.max(0, amount));
    }

    public static int getSanity(ServerPlayer player) {
        return STATES.computeIfAbsent(player.getUUID(), ignored -> new HorrorState()).sanity;
    }

    public static int getAttention(ServerPlayer player) {
        return STATES.computeIfAbsent(player.getUUID(), ignored -> new HorrorState()).attention;
    }

    private static final class HorrorState {
        private int sanity = 100;
        private int attention = 0;
    }
}
