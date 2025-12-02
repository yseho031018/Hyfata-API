package kr.hyfata.rest.api.repository.agora;

import kr.hyfata.rest.api.entity.agora.Chat;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ChatRepository extends JpaRepository<Chat, Long> {

    List<Chat> findByCreatedBy_Id(Long userId);

    List<Chat> findByType(Chat.ChatType type);

    @Query("SELECT c FROM Chat c JOIN c.participants p WHERE p.user.id = :userId ORDER BY c.updatedAt DESC")
    List<Chat> findChatsByUserId(@Param("userId") Long userId);

    @Query("SELECT c FROM Chat c JOIN c.participants p1 JOIN c.participants p2 " +
           "WHERE c.type = 'DIRECT' AND p1.user.id = :userId1 AND p2.user.id = :userId2")
    Optional<Chat> findDirectChatBetweenUsers(@Param("userId1") Long userId1, @Param("userId2") Long userId2);
}
