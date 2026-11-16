FROM stripe/stripe-cli:v1.55.11

RUN addgroup -g 1000 stripe \
    && adduser -D -u 1000 -G stripe -h /home/stripe stripe \
    && mkdir -p /home/stripe/.config/stripe \
    && chown -R stripe:stripe /home/stripe \
    && chmod 700 /home/stripe/.config/stripe

ENV XDG_CONFIG_HOME=/home/stripe/.config
ENV STRIPE_NO_AUTO_UPDATE=1

COPY --chmod=755 entrypoint.sh /usr/local/bin/stripe-dev

USER stripe
WORKDIR /home/stripe
ENTRYPOINT ["/usr/local/bin/stripe-dev"]
CMD ["listen"]
